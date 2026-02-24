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
CONTROL_UI_ALLOWED_ORIGINS=${OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS:-}
CONTROL_UI_ORIGIN_FALLBACK_RAW=${OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK-}
CONTROL_UI_ORIGIN_FALLBACK=${OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK:-auto}

ensure_dirs() {
  mkdir -p "${CONFIG_DIR}" \
    "${WORKSPACE_DIR}" \
    "${APP_HOME}/.cache/qmd" \
    "${APP_HOME}/.cache/ms-playwright" \
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

bind_mode_is_non_loopback() {
  local mode
  mode="$(printf '%s' "${BIND_MODE}" | tr '[:upper:]' '[:lower:]')"
  [[ "${mode}" != "loopback" ]]
}

control_ui_policy_patch_is_strict() {
  if bind_mode_is_non_loopback; then
    return 0
  fi

  if [[ -n "${CONTROL_UI_ALLOWED_ORIGINS}" ]] || [[ -n "${CONTROL_UI_ORIGIN_FALLBACK_RAW}" ]]; then
    return 0
  fi

  return 1
}

apply_control_ui_origin_policy() {
  local config_file="${CONFIG_DIR}/openclaw.json"
  local output=""
  local rc=0
  local js='
const fs = require("node:fs");
const path = require("node:path");

const configPath = process.argv[1];
const rawOriginsValue = String(process.argv[2] || "");
const rawFallbackValue = String(process.argv[3] || "auto");
const bindModeValue = String(process.argv[4] || "lan").trim().toLowerCase() || "lan";

if (!configPath) process.exit(0);

const nonLoopback = bindModeValue !== "loopback";
const warnings = [];

function normalizeFallback(raw) {
  const v = String(raw || "").trim().toLowerCase();
  if (v === "" || v === "auto") return { kind: "auto" };
  if (["true", "1", "yes"].includes(v)) return { kind: "bool", value: true };
  if (["false", "0", "no"].includes(v)) return { kind: "bool", value: false };
  return { kind: "invalid", raw: String(raw || "") };
}

function parseOriginEnv(raw) {
  const result = {
    hadInput: String(raw).trim().length > 0,
    values: [],
    invalidCount: 0,
    placeholderCount: 0,
  };

  if (!result.hadInput) return result;

  let candidates = null;
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      candidates = parsed.map((v) => String(v));
    }
  } catch (_) {}

  if (!candidates) {
    candidates = raw.split(",").map((v) => String(v));
  }

  const seen = new Set();
  for (const candidate of candidates) {
    const trimmed = candidate.trim();
    if (!trimmed) continue;

    if (trimmed.includes("[") || trimmed.includes("]")) {
      result.placeholderCount += 1;
      continue;
    }

    let u;
    try {
      u = new URL(trimmed);
    } catch (_) {
      result.invalidCount += 1;
      continue;
    }

    if (!["http:", "https:"].includes(u.protocol)) {
      result.invalidCount += 1;
      continue;
    }

    if (!u.hostname) {
      result.invalidCount += 1;
      continue;
    }

    if (u.pathname !== "/" || u.search || u.hash) {
      result.invalidCount += 1;
      continue;
    }

    const normalized = u.origin;
    if (!seen.has(normalized)) {
      seen.add(normalized);
      result.values.push(normalized);
    }
  }

  return result;
}

function ensureObject(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) return value;
  return {};
}

const fallbackSetting = normalizeFallback(rawFallbackValue);
if (fallbackSetting.kind === "invalid") {
  console.error(`Invalid OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK value: ${fallbackSetting.raw}. Use auto, true, or false.`);
  process.exit(64);
}

const envOrigins = parseOriginEnv(rawOriginsValue);
if (envOrigins.placeholderCount > 0) {
  warnings.push("Ignoring unresolved Control UI origin placeholder(s); relying on runtime fallback/persisted config.");
}
if (envOrigins.invalidCount > 0) {
  warnings.push(`Ignoring ${envOrigins.invalidCount} invalid Control UI origin entr${envOrigins.invalidCount === 1 ? "y" : "ies"} (use origin-only values like http://host:port).`);
}

const fileExists = fs.existsSync(configPath);
let cfg = {};
if (fileExists) {
  try {
    cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
  } catch (err) {
    console.error(`Failed to parse ${configPath}: ${err.message}`);
    process.exit(65);
  }
}

cfg = ensureObject(cfg);
cfg.gateway = ensureObject(cfg.gateway);
cfg.gateway.controlUi = ensureObject(cfg.gateway.controlUi);
const controlUi = cfg.gateway.controlUi;

const existingOrigins = Array.isArray(controlUi.allowedOrigins)
  ? controlUi.allowedOrigins.map((v) => String(v).trim()).filter(Boolean)
  : [];
const hasExistingAllowedOrigins = existingOrigins.length > 0;
const hasExistingFallback = typeof controlUi.dangerouslyAllowHostHeaderOriginFallback === "boolean";
const hasExistingPolicy = hasExistingAllowedOrigins || hasExistingFallback;

let changed = false;
let wroteExplicitOrigins = false;
let wroteFallback = false;
let autoEnabledFallback = false;

if (envOrigins.values.length > 0) {
  if (JSON.stringify(controlUi.allowedOrigins) !== JSON.stringify(envOrigins.values)) {
    controlUi.allowedOrigins = envOrigins.values;
    changed = true;
  }
  wroteExplicitOrigins = true;
}

let desiredFallback;
if (fallbackSetting.kind === "bool") {
  desiredFallback = fallbackSetting.value;
} else if (nonLoopback && !hasExistingPolicy && envOrigins.values.length === 0) {
  desiredFallback = true;
  autoEnabledFallback = true;
}

if (typeof desiredFallback === "boolean" && controlUi.dangerouslyAllowHostHeaderOriginFallback !== desiredFallback) {
  controlUi.dangerouslyAllowHostHeaderOriginFallback = desiredFallback;
  changed = true;
}
if (typeof desiredFallback === "boolean") {
  wroteFallback = true;
}

if (!changed) {
  for (const warning of warnings) console.error(`Warning: ${warning}`);
  if (wroteExplicitOrigins) {
    console.log("Control UI allowed origins already match configured values.");
  } else if (wroteFallback && !autoEnabledFallback) {
    console.log("Control UI Host-header origin fallback already matches configured value.");
  }
  process.exit(0);
}

try {
  fs.mkdirSync(path.dirname(configPath), { recursive: true });
  fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2) + "\n");
} catch (err) {
  console.error(`Failed to write ${configPath}: ${err.message}`);
  if (err && err.code === "EACCES") process.exit(73);
  process.exit(74);
}

for (const warning of warnings) console.error(`Warning: ${warning}`);
if (wroteExplicitOrigins) {
  console.log(`Applied gateway.controlUi.allowedOrigins (${envOrigins.values.length} entr${envOrigins.values.length === 1 ? "y" : "ies"}) to ${configPath}`);
}
if (autoEnabledFallback) {
  console.log("Info: auto-enabled gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback for non-loopback bind. Set OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS to harden Control UI origins.");
} else if (fallbackSetting.kind === "bool") {
  console.log(`Applied gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=${String(fallbackSetting.value)} to ${configPath}`);
}
'

  if [[ "$(id -u)" -eq 0 ]]; then
    if output="$(gosu "${APP_USER}:${APP_GROUP}" node -e "${js}" "${config_file}" "${CONTROL_UI_ALLOWED_ORIGINS}" "${CONTROL_UI_ORIGIN_FALLBACK}" "${BIND_MODE}" 2>&1)"; then
      rc=0
    else
      rc=$?
    fi
  else
    if output="$(node -e "${js}" "${config_file}" "${CONTROL_UI_ALLOWED_ORIGINS}" "${CONTROL_UI_ORIGIN_FALLBACK}" "${BIND_MODE}" 2>&1)"; then
      rc=0
    else
      rc=$?
    fi
  fi

  if [[ -n "${output}" ]]; then
    printf '%s\n' "${output}" >&2
  fi

  if [[ "${rc}" -eq 0 ]]; then
    return 0
  fi

  if [[ "${rc}" -eq 64 ]]; then
    exit 64
  fi

  if control_ui_policy_patch_is_strict; then
    echo "Could not apply Control UI origin policy to ${config_file}. Ensure ${CONFIG_DIR} is writable by the app user, or start once as root with PUID/PGID and OPENCLAW_CHOWN=auto." >&2
    exit "${rc}"
  fi

  echo "Warning: failed to apply Control UI origin policy to ${config_file}" >&2
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

  if [[ $# -eq 0 ]] || [[ "${1}" == "gateway" ]]; then
    apply_control_ui_origin_policy
    apply_trusted_proxies
    shift || true
    exec gosu "${APP_USER}:${APP_GROUP}" node dist/index.js gateway --bind "${BIND_MODE}" --port "${PORT}" --allow-unconfigured "$@"
  fi

  apply_trusted_proxies
  exec gosu "${APP_USER}:${APP_GROUP}" "$@"
fi

ensure_dirs || {
  echo "Could not create runtime directories as UID $(id -u). Check mount ownership or run once with root + PUID/PGID remap." >&2
  exit 73
}

if [[ $# -eq 0 ]] || [[ "${1}" == "gateway" ]]; then
  apply_control_ui_origin_policy
  apply_trusted_proxies
  shift || true
  exec node dist/index.js gateway --bind "${BIND_MODE}" --port "${PORT}" --allow-unconfigured "$@"
fi

apply_trusted_proxies
exec "$@"
