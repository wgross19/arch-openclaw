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

container_running_named() {
  local name="$1"
  docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null | grep -q '^true$'
}

gateway_process_running_named() {
  local name="$1"
  docker exec "${name}" sh -lc 'ps -eo cmd | grep -E "(dist/index.js gateway|openclaw-gateway)" | grep -v grep >/dev/null'
}

gateway_healthcheck_ok_named() {
  local name="$1"
  docker exec "${name}" /usr/local/bin/healthcheck.sh >/dev/null 2>&1
}

wait_for_gateway_ready_named() {
  local name="$1"
  local port="$2"
  local logs=""

  for _ in {1..60}; do
    if docker logs "${name}" 2>&1 | log_has "listening on ws://(0\\.0\\.0\\.0|127\\.0\\.0\\.1):${port}"; then
      logs="$(docker logs "${name}" 2>&1 || true)"
      printf '%s' "${logs}"
      return 0
    fi
    if container_running_named "${name}" && (gateway_healthcheck_ok_named "${name}" || gateway_process_running_named "${name}"); then
      logs="$(docker logs "${name}" 2>&1 || true)"
      printf '%s' "${logs}"
      return 0
    fi
    if ! container_running_named "${name}"; then
      break
    fi
    sleep 1
  done

  logs="$(docker logs "${name}" 2>&1 || true)"
  printf '%s' "${logs}"
  return 1
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

# 3) LAN bind control-UI-origin policy scenarios.
(
  set -euo pipefail
  tmpdir="$(mktemp -d)"
  name="openclaw-origin-auto-$$"
  token="$(openssl rand -hex 24)"
  cleanup_scenario() {
    docker rm -f "${name}" >/dev/null 2>&1 || true
    rm -rf "${tmpdir}"
  }
  trap cleanup_scenario EXIT

  docker run -d --name "${name}" \
    -e "OPENCLAW_GATEWAY_TOKEN=${token}" \
    -e "OPENCLAW_GATEWAY_BIND=lan" \
    -e "OPENCLAW_GATEWAY_PORT=18789" \
    -v "${tmpdir}:/home/node/.openclaw" \
    "${IMAGE}" >/dev/null

  logs="$(wait_for_gateway_ready_named "${name}" 18789)" || {
    echo "LAN bind auto-fallback scenario failed to start" >&2
    docker inspect -f 'container_state={{.State.Status}} exit_code={{.State.ExitCode}} error={{.State.Error}}' "${name}" >&2 || true
    printf '%s\n' "${logs}" >&2
    exit 1
  }

  if [[ ! -f "${tmpdir}/openclaw.json" ]]; then
    echo "expected ${tmpdir}/openclaw.json to be created for LAN bind auto-fallback scenario" >&2
    exit 1
  fi
  if ! rg -q '"dangerouslyAllowHostHeaderOriginFallback"[[:space:]]*:[[:space:]]*true' "${tmpdir}/openclaw.json"; then
    echo "expected auto fallback to write gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true" >&2
    cat "${tmpdir}/openclaw.json" >&2 || true
    exit 1
  fi
  if ! printf '%s' "${logs}" | log_has "auto-enabled gateway\\.controlUi\\.dangerouslyAllowHostHeaderOriginFallback"; then
    echo "expected LAN bind auto-fallback scenario logs to mention auto-enabled Host-header fallback" >&2
    printf '%s\n' "${logs}" >&2
    exit 1
  fi
)

(
  set -euo pipefail
  tmpdir="$(mktemp -d)"
  name="openclaw-origin-explicit-$$"
  token="$(openssl rand -hex 24)"
  cleanup_scenario() {
    docker rm -f "${name}" >/dev/null 2>&1 || true
    rm -rf "${tmpdir}"
  }
  trap cleanup_scenario EXIT

  docker run -d --name "${name}" \
    -e "OPENCLAW_GATEWAY_TOKEN=${token}" \
    -e "OPENCLAW_GATEWAY_BIND=lan" \
    -e "OPENCLAW_GATEWAY_PORT=18789" \
    -e 'OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=http://127.0.0.1:18800, http://localhost:18800' \
    -v "${tmpdir}:/home/node/.openclaw" \
    "${IMAGE}" >/dev/null

  logs="$(wait_for_gateway_ready_named "${name}" 18789)" || {
    echo "LAN bind explicit-origins scenario failed to start" >&2
    docker inspect -f 'container_state={{.State.Status}} exit_code={{.State.ExitCode}} error={{.State.Error}}' "${name}" >&2 || true
    printf '%s\n' "${logs}" >&2
    exit 1
  }

  if [[ ! -f "${tmpdir}/openclaw.json" ]]; then
    echo "expected ${tmpdir}/openclaw.json to be created for explicit origins scenario" >&2
    exit 1
  fi
  if ! rg -q '"allowedOrigins"' "${tmpdir}/openclaw.json"; then
    echo "expected explicit origins scenario to write gateway.controlUi.allowedOrigins" >&2
    cat "${tmpdir}/openclaw.json" >&2 || true
    exit 1
  fi
  if ! rg -q 'http://127\.0\.0\.1:18800' "${tmpdir}/openclaw.json"; then
    echo "expected explicit origins scenario to persist http://127.0.0.1:18800" >&2
    cat "${tmpdir}/openclaw.json" >&2 || true
    exit 1
  fi
  if ! rg -q 'http://localhost:18800' "${tmpdir}/openclaw.json"; then
    echo "expected explicit origins scenario to persist http://localhost:18800" >&2
    cat "${tmpdir}/openclaw.json" >&2 || true
    exit 1
  fi
  if ! printf '%s' "${logs}" | log_has "Applied gateway\\.controlUi\\.allowedOrigins"; then
    echo "expected explicit origins scenario logs to mention allowedOrigins patch" >&2
    printf '%s\n' "${logs}" >&2
    exit 1
  fi
)

set +e
docker run --rm \
  -e "OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 24)" \
  -e "OPENCLAW_GATEWAY_BIND=lan" \
  -e "OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK=maybe" \
  "${IMAGE}" gateway >/tmp/openclaw-gateway-invalid-control-ui-fallback.log 2>&1
code=$?
set -e
if [[ "${code}" -ne 64 ]]; then
  echo "expected invalid control UI fallback env to fail with exit code 64 (got ${code})" >&2
  cat /tmp/openclaw-gateway-invalid-control-ui-fallback.log >&2 || true
  exit 1
fi
if ! log_has "Invalid OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK" </tmp/openclaw-gateway-invalid-control-ui-fallback.log; then
  echo "expected invalid fallback env error message in logs" >&2
  cat /tmp/openclaw-gateway-invalid-control-ui-fallback.log >&2 || true
  exit 1
fi

(
  set -euo pipefail
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Skipping unwritable config mount smoke scenario on non-Linux host (Docker Desktop mount permissions are not strict)." >&2
    exit 0
  fi

  tmpdir="$(mktemp -d)"
  name="openclaw-origin-perms-$$"
  chmod 755 "${tmpdir}"
  cleanup_scenario() {
    docker rm -f "${name}" >/dev/null 2>&1 || true
    rm -rf "${tmpdir}"
  }
  trap cleanup_scenario EXIT

  docker run -d --name "${name}" \
    -e "OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 24)" \
    -e "OPENCLAW_GATEWAY_BIND=lan" \
    -e "OPENCLAW_CHOWN=false" \
    -v "${tmpdir}:/home/node/.openclaw" \
    "${IMAGE}" >/dev/null

  for _ in {1..20}; do
    if ! container_running_named "${name}"; then
      break
    fi
    sleep 1
  done

  logs="$(docker logs "${name}" 2>&1 || true)"
  if container_running_named "${name}"; then
    echo "expected unwritable config mount scenario to fail, but container is still running" >&2
    printf '%s\n' "${logs}" >&2
    exit 1
  fi
  if ! printf '%s' "${logs}" | log_has "Could not apply Control UI origin policy"; then
    echo "expected clear Control UI origin policy permissions failure message" >&2
    printf '%s\n' "${logs}" >&2
    exit 1
  fi
)

# 4) Gateway startup with token should not need runtime UI build.
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
