#!/usr/bin/env bash
set -euo pipefail

PORT=${OPENCLAW_GATEWAY_PORT:-18789}
URL="http://127.0.0.1:${PORT}/"

code=$(curl -sS -o /dev/null --max-time 3 -w "%{http_code}" "${URL}" || true)

case "${code}" in
  200|204|301|302|307|308|401|403)
    exit 0
    ;;
  *)
    echo "Gateway healthcheck failed (${URL} => ${code:-no-response})" >&2
    exit 1
    ;;
esac
