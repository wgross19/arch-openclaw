#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/scripts/migrate-legacy-openclaw.sh"

fail() {
  echo "migration test failed: $*" >&2
  exit 1
}

[[ -x "${SCRIPT}" ]] || fail "migration script is missing or not executable"

TMP_DIR="$(mktemp -d)"
LEGACY_DIR="${TMP_DIR}/legacy-openclaw"
TARGET_DIR="${TMP_DIR}/target-openclaw"
BACKUP_DIR="${TMP_DIR}/backups"
ENV_FILE="${TMP_DIR}/legacy.env"
OUT_ENV="${TMP_DIR}/new.env"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${LEGACY_DIR}/workspace"
cat > "${LEGACY_DIR}/openclaw.json" <<JSON
{"gateway":{"bind":"loopback","auth":{"allowTailscale":true},"tailscale":{"mode":"serve"}}}
JSON

echo "hello" > "${LEGACY_DIR}/workspace/probe.txt"
cat > "${ENV_FILE}" <<ENV
OPENCLAW_GATEWAY_TOKEN=test-token
TAILSCALE_AUTHKEY=tskey-auth-legacy
OPENAI_API_KEY=
ENV

bash "${SCRIPT}" \
  --legacy-root "${LEGACY_DIR}" \
  --target-root "${TARGET_DIR}" \
  --backup-dir "${BACKUP_DIR}" \
  --env-file "${ENV_FILE}" \
  --output-env-file "${OUT_ENV}" \
  --dry-run

bash "${SCRIPT}" \
  --legacy-root "${LEGACY_DIR}" \
  --target-root "${TARGET_DIR}" \
  --backup-dir "${BACKUP_DIR}" \
  --env-file "${ENV_FILE}" \
  --output-env-file "${OUT_ENV}"

[[ -f "${TARGET_DIR}/workspace/probe.txt" ]] || fail "workspace file not migrated"
[[ -f "${TARGET_DIR}/openclaw.json" ]] || fail "openclaw.json not migrated"
[[ -f "${OUT_ENV}" ]] || fail "mapped env file not written"

rg -q '"bind"[[:space:]]*:[[:space:]]*"0.0.0.0"' "${TARGET_DIR}/openclaw.json" || fail "bind address not updated"
if rg -q 'allowTailscale|tailscale' "${TARGET_DIR}/openclaw.json"; then
  fail "legacy tailscale fields still present"
fi

rg -q '^# DEPRECATED: TAILSCALE_AUTHKEY=' "${OUT_ENV}" || fail "deprecated env var was not marked"

ARCHIVE="$(ls -1 "${BACKUP_DIR}"/openclaw-legacy-*.tgz | head -n 1)"
[[ -n "${ARCHIVE}" ]] || fail "backup archive not created"

echo "modified" > "${TARGET_DIR}/workspace/probe.txt"
bash "${SCRIPT}" --target-root "${TARGET_DIR}" --rollback "${ARCHIVE}"

grep -q '^hello$' "${TARGET_DIR}/workspace/probe.txt" || fail "rollback did not restore workspace file"

echo "migration script test passed"
