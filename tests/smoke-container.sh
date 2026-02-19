#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"
if [[ -z "${IMAGE}" ]]; then
  echo "usage: $0 <image>" >&2
  exit 1
fi

# 1) Non-gateway command should run without a token.
docker run --rm "${IMAGE}" node --version >/dev/null

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

echo "container smoke test passed"
