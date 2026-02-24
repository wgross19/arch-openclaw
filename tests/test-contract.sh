#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_TEMPLATE="${ROOT_DIR}/templates/openclaw-unraid-cuda.xml"
POWER_TEMPLATE="${ROOT_DIR}/templates/openclaw-unraid-cuda-power.xml"
DOCKERFILE="${ROOT_DIR}/Dockerfile.unraid-cuda"
ENTRYPOINT="${ROOT_DIR}/docker/entrypoint.sh"
WORKFLOW="${ROOT_DIR}/.github/workflows/build-test-release.yml"

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

assert_template_common() {
  local template="$1"
  assert_contains "${template}" "<Network>bridge</Network>"
  assert_contains "${template}" "Target=\"/home/node/\\.openclaw\""
  assert_contains "${template}" "Target=\"OPENCLAW_GATEWAY_TOKEN\""
  assert_contains "${template}" "Target=\"OPENCLAW_TRUSTED_PROXIES\""
  assert_contains "${template}" "Target=\"OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS\""
  assert_contains "${template}" "Target=\"OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK\""
  assert_contains "${template}" "Required=\"true\""

  assert_not_contains "${template}" "TAILSCALE_AUTHKEY"
  assert_not_contains "${template}" "--cap-add=NET_ADMIN"
  assert_not_contains "${template}" "--runtime=nvidia"
  assert_not_contains "${template}" "sk-ant-"
  assert_not_contains "${template}" "sk-proj-"
  assert_not_contains "${template}" "tskey-auth"
}

[[ -f "${CORE_TEMPLATE}" ]] || fail "core template not found"
[[ -f "${POWER_TEMPLATE}" ]] || fail "power template not found"
[[ -f "${DOCKERFILE}" ]] || fail "dockerfile not found"
[[ -f "${ENTRYPOINT}" ]] || fail "entrypoint not found"

assert_template_common "${CORE_TEMPLATE}"
assert_template_common "${POWER_TEMPLATE}"
assert_not_contains "${CORE_TEMPLATE}" "/home/node/\.cache/ms-playwright"
assert_contains "${POWER_TEMPLATE}" "<Name>OpenClaw-CUDA-Power</Name>"
assert_contains "${POWER_TEMPLATE}" "<Repository>[^<]+:power-(beta|stable)</Repository>"
assert_contains "${POWER_TEMPLATE}" "Target=\"/home/node/\.cache/ms-playwright\""

assert_contains "${ROOT_DIR}/.openclaw-ref" "^v2026\.2\.23$"

assert_contains "${DOCKERFILE}" "nvidia/cuda:13\.1\.1-runtime-ubuntu22\.04@sha256:[a-f0-9]{64}"
assert_contains "${DOCKERFILE}" "ARG QMD_VERSION=1\.0\.7"
assert_contains "${DOCKERFILE}" "ARG QMD_URL_AMD64=https://registry\.npmjs\.org/@tobilu/qmd/-/qmd-1\.0\.7\.tgz"
assert_contains "${DOCKERFILE}" "ARG QMD_SHA256_AMD64=[a-f0-9]{64}"
assert_contains "${DOCKERFILE}" "ARG BUN_VERSION=1\.3\.9"
assert_contains "${DOCKERFILE}" "ARG UV_VERSION=0\.10\.5"
assert_contains "${DOCKERFILE}" "ARG GH_VERSION=2\.87\.3"
assert_contains "${DOCKERFILE}" "ARG PLAYWRIGHT_VERSION=1\.58\.2"
assert_contains "${DOCKERFILE}" "ARG HOMEBREW_BREW_COMMIT=[a-f0-9]{40}"
assert_contains "${DOCKERFILE}" "FROM runtime-base AS runtime-core"
assert_contains "${DOCKERFILE}" "FROM runtime-core AS runtime-power"
assert_contains "${DOCKERFILE}" "FROM runtime-core AS runtime$"
assert_contains "${DOCKERFILE}" "COPY --from=tooling-fetcher /opt/tooling/bin/bun /usr/local/bin/bun"
assert_contains "${DOCKERFILE}" "COPY --from=tooling-fetcher /opt/tooling/bin/uv /usr/local/bin/uv"
assert_contains "${DOCKERFILE}" "COPY --from=tooling-fetcher /opt/tooling/bin/gh /usr/local/bin/gh"
assert_contains "${DOCKERFILE}" "npm install -g --omit=dev /tmp/qmd\.tgz"
assert_contains "${DOCKERFILE}" "ln -sf \.\./lib/node_modules/@tobilu/qmd/qmd /usr/local/bin/qmd"
assert_contains "${DOCKERFILE}" "qmd --version"
assert_contains "${DOCKERFILE}" "ffmpeg"
assert_contains "${DOCKERFILE}" "ripgrep"
assert_contains "${DOCKERFILE}" "tmux"
assert_contains "${DOCKERFILE}" "HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew"
assert_contains "${DOCKERFILE}" "PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright"
assert_contains "${DOCKERFILE}" "playwright/cli\.js install"
assert_contains "${DOCKERFILE}" "CMD \[\"gateway\"\]"

assert_contains "${ENTRYPOINT}" "gosu \"\\$\\{APP_USER\\}:\\$\\{APP_GROUP\\}\" node dist/index\.js gateway"
assert_contains "${ENTRYPOINT}" "CHOWN_MODE=\\$\\{OPENCLAW_CHOWN:-auto\\}"
assert_contains "${ENTRYPOINT}" "groupmod --non-unique --gid"
assert_contains "${ENTRYPOINT}" "usermod --non-unique --uid"
assert_contains "${ENTRYPOINT}" "\\.cache/ms-playwright"
assert_contains "${ENTRYPOINT}" "OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS"
assert_contains "${ENTRYPOINT}" "OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK"
assert_contains "${ENTRYPOINT}" "gateway\\.controlUi\\.allowedOrigins"
assert_contains "${ENTRYPOINT}" "dangerouslyAllowHostHeaderOriginFallback"

assert_contains "${WORKFLOW}" "matrix:"
assert_contains "${WORKFLOW}" "profile: \[core, power\]"
assert_contains "${WORKFLOW}" "target: runtime-\\$\\{\\{ matrix\.profile \\}\\}"
assert_contains "${WORKFLOW}" "tests/smoke-container\.sh local/openclaw-unraid-cuda:\\$\\{\\{ matrix\.profile \\}\\}-test \\$\\{\\{ matrix\.profile \\}\\}"
assert_contains "${WORKFLOW}" "profile_channel_tag=\"power-\\$\\{channel\\}\""
assert_contains "${WORKFLOW}" "extra_stable_alias=\"power\""
assert_contains "${WORKFLOW}" "templates/openclaw-unraid-cuda-power\.xml"
assert_contains "${WORKFLOW}" "Validate Trivy exception policy"
assert_contains "${WORKFLOW}" "trivyignores: \.trivyignore"

assert_contains "${ROOT_DIR}/.trivyignore.yaml" "expired_at:"
assert_contains "${ROOT_DIR}/.trivyignore.yaml" "statement:"
assert_contains "${ROOT_DIR}/.trivyignore" "CVE-"

assert_not_contains "${DOCKERFILE}" "pkgs\.tailscale\.com"
assert_not_contains "${DOCKERFILE}" "brew install .*qmd"
assert_not_contains "${ENTRYPOINT}" "tailscaled"

echo "contract test passed"
