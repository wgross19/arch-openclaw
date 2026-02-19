#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  unraid-debug-cycle.sh [options] [-- <command>]

Description:
  Runs a repeatable Unraid debug cycle for OpenClaw:
  1) fixes host appdata ownership/perms
  2) restarts the target container
  3) captures live watcher samples + filtered container logs
  4) runs an interactive command inside the container (default: openclaw onboard)
  5) prints a paste-ready capture tail

Options:
  --container NAME         Container name (default: OpenClaw-Unraid-CUDA)
  --appdata PATH           Host appdata path (default: /mnt/user/appdata/openclaw-cuda/test8)
  --run-as UID:GID         docker exec user for interactive command (default: 99:100)
  --interval SEC           Watcher sampling interval seconds (default: 3)
  --tail-lines N           Lines to print from capture at end (default: 500)
  --no-fix-perms           Skip host chown/chmod repair step
  -h, --help               Show help

Examples:
  scripts/unraid-debug-cycle.sh
  scripts/unraid-debug-cycle.sh --appdata /mnt/user/appdata/openclaw-cuda/test9
  scripts/unraid-debug-cycle.sh -- -- sh -lc 'openclaw devices list'
USAGE
}

CONTAINER="OpenClaw-Unraid-CUDA"
APPDATA="/mnt/user/appdata/openclaw-cuda/test8"
RUN_AS="99:100"
INTERVAL=3
TAIL_LINES=500
FIX_PERMS=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container)
      CONTAINER="$2"
      shift 2
      ;;
    --appdata)
      APPDATA="$2"
      shift 2
      ;;
    --run-as)
      RUN_AS="$2"
      shift 2
      ;;
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --tail-lines)
      TAIL_LINES="$2"
      shift 2
      ;;
    --no-fix-perms)
      FIX_PERMS=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  CMD=("$@")
else
  CMD=("openclaw" "onboard")
fi

command -v docker >/dev/null 2>&1 || {
  echo "docker not found on PATH" >&2
  exit 127
}

if [[ ! -d "${APPDATA}" ]]; then
  echo "appdata path does not exist: ${APPDATA}" >&2
  exit 2
fi

TS="$(date +%Y%m%d-%H%M%S)"
CAPTURE="/tmp/${CONTAINER}-capture-${TS}.log"

cleanup() {
  if [[ -n "${WATCH_PID:-}" ]]; then
    kill "${WATCH_PID}" >/dev/null 2>&1 || true
    wait "${WATCH_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ "${FIX_PERMS}" -eq 1 ]]; then
  docker stop "${CONTAINER}" >/dev/null 2>&1 || true
  chown -R 99:100 "${APPDATA}"
  find "${APPDATA}" -type d -exec chmod 775 {} +
  find "${APPDATA}" -type f -exec chmod 664 {} +
fi

docker start "${CONTAINER}" >/dev/null

{
  echo "=== START $(date -Is) ==="
  echo "container=${CONTAINER}"
  echo "appdata=${APPDATA}"
  echo "run_as=${RUN_AS}"
  echo "command=${CMD[*]}"
  echo "capture=${CAPTURE}"
  echo
  echo "=== host perms snapshot ==="
  ls -ld "${APPDATA}" "${APPDATA}/workspace" 2>/dev/null || true
  ls -l "${APPDATA}/openclaw.json" "${APPDATA}/openclaw.json.bak" 2>/dev/null || true
  echo
  echo "=== container identity snapshot ==="
  docker exec "${CONTAINER}" sh -lc 'id; ps -eo pid,uid,gid,user,group,cmd | grep -E "dist/index.js gateway|openclaw" | grep -v grep || true'
  echo
  echo "=== read probes ==="
  docker exec --user 99:100 "${CONTAINER}" sh -lc 'head -n1 /home/node/.openclaw/openclaw.json >/dev/null && echo "99:100 read OK" || echo "99:100 read FAIL"'
  docker exec --user 1000:1000 "${CONTAINER}" sh -lc 'head -n1 /home/node/.openclaw/openclaw.json >/dev/null && echo "1000:1000 read OK" || echo "1000:1000 read FAIL"'
  echo
} > "${CAPTURE}" 2>&1

(
  while true; do
    {
      echo "=== SAMPLE $(date -Is) ==="
      docker exec "${CONTAINER}" sh -lc 'stat -c "json %u:%g %a %n" /home/node/.openclaw/openclaw.json 2>/dev/null || echo "json missing"'
      docker exec "${CONTAINER}" sh -lc 'ps -eo pid,uid,gid,user,group,cmd | grep -E "dist/index.js gateway|openclaw" | grep -v grep || true'
      docker logs --since "${INTERVAL}s" "${CONTAINER}" 2>&1 | egrep -i "EACCES|openclaw.json|device token mismatch|pairing required|trustedProxies|unauthorized" || true
      echo
    } >> "${CAPTURE}" 2>&1
    sleep "${INTERVAL}"
  done
) &
WATCH_PID=$!

set +e
docker exec -it --user "${RUN_AS}" "${CONTAINER}" "${CMD[@]}"
RC=$?
set -e

{
  echo "=== END $(date -Is) rc=${RC} ==="
  docker exec "${CONTAINER}" sh -lc 'stat -c "final %u:%g %a %n" /home/node/.openclaw/openclaw.json 2>/dev/null || true'
  echo
  echo "=== final logs tail ==="
  docker logs --tail 200 "${CONTAINER}" 2>&1 || true
} >> "${CAPTURE}" 2>&1

echo "Capture file: ${CAPTURE}"
echo "----- paste this block -----"
tail -n "${TAIL_LINES}" "${CAPTURE}"
exit "${RC}"
