#!/usr/bin/env bash
set -euo pipefail

LEGACY_ROOT="/mnt/user/appdata/openclaw"
TARGET_ROOT="/mnt/user/appdata/openclaw"
BACKUP_DIR="/mnt/user/appdata/openclaw-migration-backups"
ENV_FILE=""
OUTPUT_ENV_FILE=""
DRY_RUN="false"
FORCE="false"
ROLLBACK_ARCHIVE=""
BACKUP_ARCHIVE=""

DEPRECATED_VARS=(
  TAILSCALE_AUTHKEY
)

REMOVED_MOUNTS=(
  /var/lib/tailscale
)

usage() {
  cat <<USAGE
Usage:
  migrate-legacy-openclaw.sh [options]

Options:
  --legacy-root <path>      Legacy OpenClaw appdata root (default: ${LEGACY_ROOT})
  --target-root <path>      New OpenClaw appdata root (default: ${TARGET_ROOT})
  --backup-dir <path>       Backup output directory (default: ${BACKUP_DIR})
  --env-file <path>         Legacy .env file to map/deprecate variables
  --output-env-file <path>  Write transformed env output to this path
  --rollback <archive.tgz>  Restore from backup archive
  --dry-run                 Print actions without changing files
  --force                   Continue even if warnings are raised
  -h, --help                Show this help text
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log "DRY-RUN: $*"
    return 0
  fi

  "$@"
}

require_path_exists() {
  local p="$1"
  if [[ ! -e "${p}" ]]; then
    log "ERROR: Required path does not exist: ${p}"
    exit 1
  fi
}

contains_deprecated_var() {
  local key="$1"
  for item in "${DEPRECATED_VARS[@]}"; do
    if [[ "${item}" == "${key}" ]]; then
      return 0
    fi
  done
  return 1
}

map_env_file() {
  local in_file="$1"
  local out_file="$2"

  require_path_exists "${in_file}"
  log "Generating mapped env file: ${out_file}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  : > "${out_file}"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*# ]] || [[ -z "${line}" ]]; then
      printf '%s\n' "${line}" >> "${out_file}"
      continue
    fi

    key="${line%%=*}"
    if contains_deprecated_var "${key}"; then
      printf '# DEPRECATED: %s\n' "${line}" >> "${out_file}"
      continue
    fi

    printf '%s\n' "${line}" >> "${out_file}"
  done < "${in_file}"
}

backup_legacy() {
  local stamp staging payload
  stamp="$(date '+%Y%m%d-%H%M%S')-$$"
  BACKUP_ARCHIVE="${BACKUP_DIR}/openclaw-legacy-${stamp}.tgz"

  run_cmd mkdir -p "${BACKUP_DIR}"

  log "Creating backup archive: ${BACKUP_ARCHIVE}"
  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  staging="$(mktemp -d)"
  payload="${staging}/payload"
  mkdir -p "${payload}"

  rsync -a "${LEGACY_ROOT}" "${payload}/"
  if [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]]; then
    cp -a "${ENV_FILE}" "${payload}/"
  fi

  tar -C "${payload}" -czf "${BACKUP_ARCHIVE}" .
  rm -rf "${staging}"

  log "Backup complete: ${BACKUP_ARCHIVE}"
}

transform_files() {
  log "Transforming legacy data into target structure"
  run_cmd mkdir -p "${TARGET_ROOT}" "${TARGET_ROOT}/workspace"

  if [[ "${LEGACY_ROOT}" != "${TARGET_ROOT}" ]]; then
    run_cmd rsync -a --delete "${LEGACY_ROOT}/" "${TARGET_ROOT}/"
  fi

  if [[ -f "${TARGET_ROOT}/openclaw.json" ]] && command -v jq >/dev/null 2>&1; then
    log "Updating openclaw.json defaults for Unraid-hosted Tailscale model"
    if [[ "${DRY_RUN}" != "true" ]]; then
      local tmp_json
      tmp_json="${TARGET_ROOT}/openclaw.json.tmp"
      jq '
        .gateway.bind = "0.0.0.0"
        | del(.gateway.auth.allowTailscale)
        | del(.gateway.tailscale)
      ' "${TARGET_ROOT}/openclaw.json" > "${tmp_json}" && mv "${tmp_json}" "${TARGET_ROOT}/openclaw.json"
    fi
  fi

  # Ensure recommended directories exist even if mounts are optional.
  run_cmd mkdir -p "${TARGET_ROOT}/workspace"
}

validate_result() {
  log "Running migration validation"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "DRY-RUN: skipping filesystem validation checks"
    return 0
  fi

  if [[ ! -d "${TARGET_ROOT}" ]]; then
    log "ERROR: Target root is missing: ${TARGET_ROOT}"
    exit 1
  fi

  if [[ ! -d "${TARGET_ROOT}/workspace" ]]; then
    log "ERROR: Workspace path missing: ${TARGET_ROOT}/workspace"
    exit 1
  fi

  if [[ ! -f "${TARGET_ROOT}/openclaw.json" ]]; then
    log "WARN: openclaw.json not found in target. First-run generation will create it."
  fi

  for mount in "${REMOVED_MOUNTS[@]}"; do
    if [[ -d "${TARGET_ROOT}${mount}" ]]; then
      log "WARN: Legacy mount path still present under target: ${TARGET_ROOT}${mount}"
    fi
  done

  log "Validation complete"
}

rollback_from_archive() {
  local archive="$1"
  local restore_dir temp_restore stamp

  require_path_exists "${archive}"
  stamp="$(date '+%Y%m%d-%H%M%S')-$$"
  temp_restore="$(mktemp -d)"
  restore_dir="${temp_restore}/restore"

  run_cmd mkdir -p "${restore_dir}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "DRY-RUN rollback complete"
    return 0
  fi

  tar -xzf "${archive}" -C "${restore_dir}"

  if [[ -d "${TARGET_ROOT}" ]]; then
    mv "${TARGET_ROOT}" "${TARGET_ROOT}.pre-rollback-${stamp}"
  fi

  mkdir -p "$(dirname "${TARGET_ROOT}")"
  local extracted
  extracted="$(find "${restore_dir}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "${extracted}" ]]; then
    log "ERROR: Could not find extracted backup content"
    exit 1
  fi

  mv "${extracted}" "${TARGET_ROOT}"
  rm -rf "${temp_restore}"

  log "Rollback restored to: ${TARGET_ROOT}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --legacy-root)
      LEGACY_ROOT="$2"
      shift 2
      ;;
    --target-root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    --backup-dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --output-env-file)
      OUTPUT_ENV_FILE="$2"
      shift 2
      ;;
    --rollback)
      ROLLBACK_ARCHIVE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "ERROR: Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -n "${ROLLBACK_ARCHIVE}" ]]; then
  log "Running rollback mode"
  rollback_from_archive "${ROLLBACK_ARCHIVE}"
  exit 0
fi

log "Running migration mode"
require_path_exists "${LEGACY_ROOT}"

if [[ "${LEGACY_ROOT}" == "${TARGET_ROOT}" ]]; then
  log "INFO: Legacy and target roots are the same path; migration will be in-place."
fi

if [[ -n "${ENV_FILE}" && -z "${OUTPUT_ENV_FILE}" ]]; then
  OUTPUT_ENV_FILE="${ENV_FILE}.v1"
fi

if [[ -n "${ENV_FILE}" && ! -f "${ENV_FILE}" ]]; then
  if [[ "${FORCE}" == "true" ]]; then
    log "WARN: --env-file path not found; continuing because --force is set"
  else
    log "ERROR: --env-file path not found: ${ENV_FILE}"
    exit 1
  fi
fi

backup_legacy
transform_files
validate_result

if [[ -n "${ENV_FILE}" && -n "${OUTPUT_ENV_FILE}" && -f "${ENV_FILE}" ]]; then
  map_env_file "${ENV_FILE}" "${OUTPUT_ENV_FILE}"
  log "Mapped env file written to: ${OUTPUT_ENV_FILE}"
fi

log "Migration complete"
log "Backup archive: ${BACKUP_ARCHIVE}"
log "If rollback is needed, run: $(basename "$0") --target-root ${TARGET_ROOT} --rollback ${BACKUP_ARCHIVE}"
