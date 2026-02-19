#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT_DIR}/templates/openclaw-unraid-cuda.xml"
DOCKERFILE="${ROOT_DIR}/Dockerfile.unraid-cuda"
ENTRYPOINT="${ROOT_DIR}/docker/entrypoint.sh"

fail() {
  echo "contract test failed: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  rg -q --multiline -- "${pattern}" "${file}" || fail "${file} missing pattern: ${pattern}"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if rg -q --multiline -- "${pattern}" "${file}"; then
    fail "${file} contains forbidden pattern: ${pattern}"
  fi
}

[[ -f "${TEMPLATE}" ]] || fail "template not found"
[[ -f "${DOCKERFILE}" ]] || fail "dockerfile not found"
[[ -f "${ENTRYPOINT}" ]] || fail "entrypoint not found"

assert_contains "${TEMPLATE}" "<Network>bridge</Network>"
assert_contains "${TEMPLATE}" "Target=\"/home/node/\\.openclaw\""
assert_contains "${TEMPLATE}" "Target=\"OPENCLAW_GATEWAY_TOKEN\""
assert_contains "${TEMPLATE}" "Required=\"true\""

assert_not_contains "${TEMPLATE}" "TAILSCALE_AUTHKEY"
assert_not_contains "${TEMPLATE}" "--cap-add=NET_ADMIN"
assert_not_contains "${TEMPLATE}" "--runtime=nvidia"
assert_not_contains "${TEMPLATE}" "sk-ant-"
assert_not_contains "${TEMPLATE}" "sk-proj-"
assert_not_contains "${TEMPLATE}" "tskey-auth"

assert_contains "${DOCKERFILE}" "nvidia/cuda:12\\.2\\.2-runtime-ubuntu22\\.04"
assert_contains "${DOCKERFILE}" "CMD \[\"gateway\"\]"
assert_contains "${ENTRYPOINT}" "gosu \"\\$\\{APP_USER\\}:\\$\\{APP_GROUP\\}\" node dist/index\\.js gateway"
assert_contains "${ENTRYPOINT}" "CHOWN_MODE=\\$\\{OPENCLAW_CHOWN:-auto\\}"
assert_contains "${ENTRYPOINT}" "groupmod --non-unique --gid"
assert_contains "${ENTRYPOINT}" "usermod --non-unique --uid"

assert_not_contains "${DOCKERFILE}" "pkgs\\.tailscale\\.com"
assert_not_contains "${ENTRYPOINT}" "tailscaled"

echo "contract test passed"
