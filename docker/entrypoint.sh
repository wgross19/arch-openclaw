#!/usr/bin/env bash
set -euo pipefail

APP_USER=node
APP_GROUP=node
APP_HOME=/home/node
CONFIG_DIR=${OPENCLAW_CONFIG_DIR:-/home/node/.openclaw}
WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR:-${CONFIG_DIR}/workspace}
PORT=${OPENCLAW_GATEWAY_PORT:-18789}
BIND_MODE=${OPENCLAW_GATEWAY_BIND:-lan}

ensure_dirs() {
  mkdir -p "${CONFIG_DIR}" \
    "${WORKSPACE_DIR}" \
    "${APP_HOME}/.cache/qmd" \
    "${APP_HOME}/.bun" \
    "/home/linuxbrew/.linuxbrew"
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
    groupmod --gid "${PGID}" "${APP_GROUP}"
  fi

  if [[ -n "${PUID:-}" ]] && [[ "${PUID}" != "$(id -u ${APP_USER})" ]]; then
    usermod --uid "${PUID}" "${APP_USER}"
  fi

  ensure_dirs

  if [[ "${OPENCLAW_CHOWN:-false}" == "true" ]]; then
    chown -R "${APP_USER}:${APP_GROUP}" "${CONFIG_DIR}" "${WORKSPACE_DIR}" "${APP_HOME}/.cache" "${APP_HOME}/.bun" "/home/linuxbrew"
  fi

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

if [[ $# -eq 0 ]] || [[ "${1}" == "gateway" ]]; then
  shift || true
  exec node dist/index.js gateway --bind "${BIND_MODE}" --port "${PORT}" --allow-unconfigured "$@"
fi

exec "$@"
