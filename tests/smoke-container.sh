#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"
PROFILE="${2:-core}"
SKIP_UV_CHECKS="${ARCH_OPENCLAW_SMOKE_SKIP_UV_CHECKS:-0}"
if [[ -z "${IMAGE}" ]]; then
  echo "usage: $0 <image> [core|power]" >&2
  exit 1
fi
if [[ "${PROFILE}" != "core" && "${PROFILE}" != "power" ]]; then
  echo "profile must be core or power (got ${PROFILE})" >&2
  exit 1
fi
if [[ "${SKIP_UV_CHECKS}" != "0" && "${SKIP_UV_CHECKS}" != "1" ]]; then
  echo "ARCH_OPENCLAW_SMOKE_SKIP_UV_CHECKS must be 0 or 1 (got ${SKIP_UV_CHECKS})" >&2
  exit 1
fi

log_has() {
  local pattern="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -q -- "${pattern}"
  else
    grep -Eq -- "${pattern}"
  fi
}

container_running() {
  docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null | grep -q '^true$'
}

gateway_process_running() {
  docker exec "${CONTAINER_NAME}" sh -lc 'ps -eo cmd | grep -E "(dist/index.js gateway|openclaw-gateway)" | grep -v grep >/dev/null'
}

gateway_healthcheck_ok() {
  docker exec "${CONTAINER_NAME}" /usr/local/bin/healthcheck.sh >/dev/null 2>&1
}

# 1) Non-gateway commands should run without a token.
docker run --rm "${IMAGE}" node --version >/dev/null
docker run --rm "${IMAGE}" openclaw --help >/dev/null
docker run --rm "${IMAGE}" qmd --version >/dev/null
docker run --rm -e "ARCH_OPENCLAW_SMOKE_SKIP_UV_CHECKS=${SKIP_UV_CHECKS}" "${IMAGE}" sh -lc '
  test "$(command -v qmd)" = "/usr/local/bin/qmd"
  qmd --help >/dev/null
  bun --version >/dev/null
  ffmpeg -version >/dev/null
  ffprobe -version >/dev/null
  git --version >/dev/null
  jq --version >/dev/null
  rg --version >/dev/null
  tmux -V >/dev/null
  python3 --version >/dev/null
  if [ "${ARCH_OPENCLAW_SMOKE_SKIP_UV_CHECKS:-0}" = "1" ]; then
    echo "Skipping uv smoke check (ARCH_OPENCLAW_SMOKE_SKIP_UV_CHECKS=1)" >&2
  else
    uv --version >/dev/null
  fi
  gh --version >/dev/null
  mkdir -p /home/node/.cache/qmd /home/node/.bun
  test -w /home/node/.cache/qmd
  test -w /home/node/.bun
  touch /home/node/.cache/qmd/.smoke-write
  touch /home/node/.bun/.smoke-write
' >/dev/null

if [[ "${PROFILE}" == "power" ]]; then
  docker run --rm "${IMAGE}" sh -lc '
    command -v brew >/dev/null
    brew --version >/dev/null
    test -n "${PLAYWRIGHT_BROWSERS_PATH:-}"
    test "${PLAYWRIGHT_BROWSERS_PATH}" = "/home/node/.cache/ms-playwright"
    mkdir -p /home/node/.cache/ms-playwright /home/linuxbrew/.linuxbrew
    test -w /home/node/.cache/ms-playwright
    test -w /home/linuxbrew/.linuxbrew
    find "${PLAYWRIGHT_BROWSERS_PATH}" -maxdepth 5 -type f | grep -Eq "(chrome|chromium)"
  ' >/dev/null
fi

# 2) Gateway command should fail fast when token is missing.
set +e
docker run --rm "${IMAGE}" gateway >/tmp/openclaw-gateway-missing-token.log 2>&1
code=$?
set -e

if [[ "${code}" -ne 64 ]]; then
  echo "expected gateway to fail with exit code 64 when OPENCLAW_GATEWAY_TOKEN is missing (got ${code})" >&2
  cat /tmp/openclaw-gateway-missing-token.log >&2 || true
  exit 1
fi

# 3) Gateway startup with token should not need runtime UI build.
CONTAINER_NAME="openclaw-smoke-${PROFILE}-$$"
TOKEN="$(openssl rand -hex 24)"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "${CONTAINER_NAME}" \
  -e "OPENCLAW_GATEWAY_TOKEN=${TOKEN}" \
  -e "OPENCLAW_GATEWAY_PORT=18789" \
  -e "OPENCLAW_GATEWAY_BIND=loopback" \
  "${IMAGE}" >/dev/null

for _ in {1..60}; do
  if docker logs "${CONTAINER_NAME}" 2>&1 | log_has "listening on ws://(0\\.0\\.0\\.0|127\\.0\\.0\\.1):18789"; then
    break
  fi
  if container_running && gateway_healthcheck_ok; then
    break
  fi
  if ! container_running; then
    break
  fi
  sleep 1
done

LOGS="$(docker logs "${CONTAINER_NAME}" 2>&1 || true)"
if ! printf '%s' "${LOGS}" | log_has "listening on ws://(0\\.0\\.0\\.0|127\\.0\\.0\\.1):18789"; then
  # Newer OpenClaw builds may not always emit the old "listening on ..." log line.
  # Treat an in-container healthcheck response or live gateway process as readiness.
  if container_running && (gateway_healthcheck_ok || gateway_process_running); then
    echo "gateway is reachable without explicit listening log line; continuing smoke test" >&2
  else
    echo "gateway did not reach listening state during smoke test" >&2
    docker inspect -f 'container_state={{.State.Status}} exit_code={{.State.ExitCode}} error={{.State.Error}}' "${CONTAINER_NAME}" >&2 || true
    docker ps -a --filter "name=${CONTAINER_NAME}" >&2 || true
    printf '%s\n' "${LOGS}" >&2
    exit 1
  fi
fi

if printf '%s' "${LOGS}" | log_has "Control UI assets missing; building|Control UI build failed"; then
  echo "runtime UI build path was triggered; image should ship prebuilt UI assets" >&2
  printf '%s\n' "${LOGS}" >&2
  exit 1
fi

echo "container smoke test passed (${PROFILE})"
