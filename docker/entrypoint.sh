#!/usr/bin/env bash
set -euo pipefail

APP_USER=node
APP_GROUP=node
APP_HOME=/home/node
CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-/home/node/.openclaw}
WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR:-${CONFIG_DIR}/workspace}
PORT=${OPENCLAW_GATEWAY_PORT:-18789}
BIND_MODE=${OPENCLAW_GATEWAY_BIND:-lan}
CHOWN_MODE=${OPENCLAW_CHOWN:-auto}
TRUSTED_PROXIES=${OPENCLAW_TRUSTED_PROXIES:-}

ensure_dirs() {
  mkdir -p "${CONFIG_DIR}" \
    "${WORKSPACE_DIR}" \
    "${APP_HOME}/.cache/qmd" \
    "${APP_HOME}/.bun" \
    "/home/linuxbrew/.linuxbrew"
}

app_user_has_rw() {
  local path="$1"
  gosu "${APP_USER}:${APP_GROUP}" test -r "${path}" && gosu "${APP_USER}:${APP_GROUP}" test -w "${path}"
}

auto_mode_needs_chown() {
  local path

  for path in "${CONFIG_DIR}" "${WORKSPACE_DIR}"; do
    if ! app_user_has_rw "${path}"; then
      return 0
    fi
  done

  for path in \
    "${CONFIG_DIR}/openclaw.json" \
    "${CONFIG_DIR}/openclaw.json.bak" \
    "${CONFIG_DIR}/canvas" \
    "${CONFIG_DIR}/cron" \
    "${CONFIG_DIR}/agents"; do
    if [[ -e "${path}" ]] && ! app_user_has_rw "${path}"; then
      return 0
    fi
  done

  return 1
}

apply_trusted_proxies() {
  local config_file="${CONFIG_DIR}/openclaw.json"
  local js='
const fs = require("node:fs");
const configPath = process.argv[1];
const rawValue = process.argv[2];
if (!configPath || !rawValue) process.exit(0);

let proxies = null;
try {
  const parsed = JSON.parse(rawValue);
  if (Array.isArray(parsed)) {
    proxies = parsed.map((item) => String(item).trim()).filter(Boolean);
  }
} catch (_) {}

if (!proxies) {
  proxies = rawValue.split(",").map((item) => item.trim()).filter(Boolean);
}
if (!proxies.length) process.exit(0);

const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
cfg.gateway = cfg.gateway || {};
cfg.gateway.trustedProxies = proxies;
fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2) + "\n");
'

  if [[ -z "${TRUSTED_PROXIES}" ]] || [[ ! -f "${config_file}" ]]; then
    return 0
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    if ! gosu "${APP_USER}:${APP_GROUP}" node -e "${js}" "${config_file}" "${TRUSTED_PROXIES}" >/dev/null 2>&1; then
      echo "Warning: failed to apply OPENCLAW_TRUSTED_PROXIES to ${config_file}" >&2
    fi
    return 0
  fi

  if ! node -e "${js}" "${config_file}" "${TRUSTED_PROXIES}" >/dev/null 2>&1; then
    echo "Warning: failed to apply OPENCLAW_TRUSTED_PROXIES to ${config_file}" >&2
  fi
}

needs_chown() {
  local mode
  mode="$(printf '%s' "${CHOWN_MODE}" | tr '[:upper:]' '[:lower:]')"

  case "${mode}" in
    true|1|always)
      return 0
      ;;
    false|0|never)
      return 1
      ;;
    auto|"")
      auto_mode_needs_chown
      return $?
      ;;
    *)
      echo "Invalid OPENCLAW_CHOWN value: ${CHOWN_MODE}. Use auto, true, or false." >&2
      exit 64
      ;;
  esac
}

requires_gateway_token() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  if [[ "${1}" == "gateway" ]]; then
    return 0
  fi

  if [[ "${*}" == *"dist/index.js gateway"* ]]; then
    return 0
  fi

  return 1
}

if requires_gateway_token "$@" && [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  echo "OPENCLAW_GATEWAY_TOKEN is required to start the gateway." >&2
  exit 64
fi

if [[ "$(id -u)" -eq 0 ]]; then
  if [[ -n "${PGID:-}" ]] && [[ "${PGID}" != "$(id -g ${APP_GROUP})" ]]; then
    groupmod --non-unique --gid "${PGID}" "${APP_GROUP}"
  fi

  if [[ -n "${PUID:-}" ]] && [[ "${PUID}" != "$(id -u ${APP_USER})" ]]; then
    usermod --non-unique --uid "${PUID}" "${APP_USER}"
  fi

  ensure_dirs

  if needs_chown; then
    chown -R "${APP_USER}:${APP_GROUP}" "${CONFIG_DIR}" "${WORKSPACE_DIR}" "${APP_HOME}/.cache" "${APP_HOME}/.bun" "/home/linuxbrew"
  fi

  apply_trusted_proxies

  if [[ $# -eq 0 ]] || [[ "${1}" == "gateway" ]]; then
    shift || true
    exec gosu "${APP_USER}:${APP_GROUP}" node dist/index.js gateway --bind "${BIND_MODE}" --port "${PORT}" --allow-unconfigured "$@"
  fi

  exec gosu "${APP_USER}:${APP_GROUP}" "$@"
fi

ensure_dirs || {
  echo "Could not create runtime directories as UID $(id -u). Check mount ownership or run once with root + PUID/PGID remap." >&2
  exit 73
}

apply_trusted_proxies

if [[ $# -eq 0 ]] || [[ "${1}" == "gateway" ]]; then
  shift || true
  exec node dist/index.js gateway --bind "${BIND_MODE}" --port "${PORT}" --allow-unconfigured "$@"
fi

exec "$@"
