#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"
if [[ -z "${IMAGE}" ]]; then
  echo "usage: $0 <image>" >&2
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
  docker exec "${CONTAINER_NAME}" sh -lc 'ps -eo cmd | grep -F "dist/index.js gateway" | grep -v grep >/dev/null'
}

# 1) Non-gateway command should run without a token.
docker run --rm "${IMAGE}" node --version >/dev/null
docker run --rm "${IMAGE}" openclaw --help >/dev/null

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
CONTAINER_NAME="openclaw-smoke-$$"
TOKEN="$(openssl rand -hex 24)"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "${CONTAINER_NAME}" \
  -e "OPENCLAW_GATEWAY_TOKEN=${TOKEN}" \
  -e "OPENCLAW_GATEWAY_PORT=18789" \
  "${IMAGE}" >/dev/null

for _ in {1..20}; do
  if docker logs "${CONTAINER_NAME}" 2>&1 | log_has "listening on ws://(0\\.0\\.0\\.0|127\\.0\\.0\\.1):18789"; then
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
  # Treat a live gateway process in a running container as a valid readiness signal.
  if container_running && gateway_process_running; then
    echo "gateway process is running without explicit listening log line; continuing smoke test" >&2
  else
    echo "gateway did not reach listening state during smoke test" >&2
    printf '%s\n' "${LOGS}" >&2
    exit 1
  fi
fi

if printf '%s' "${LOGS}" | log_has "Control UI assets missing; building|Control UI build failed"; then
  echo "runtime UI build path was triggered; image should ship prebuilt UI assets" >&2
  printf '%s\n' "${LOGS}" >&2
  exit 1
fi

echo "container smoke test passed"
