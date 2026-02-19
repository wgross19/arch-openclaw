#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_PATH="templates/openclaw-unraid-cuda.xml"
CHANNEL="stable"

usage() {
  cat <<USAGE
Usage: $0 [--template PATH] [--channel stable|beta]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE_PATH="$2"
      shift 2
      ;;
    --channel)
      CHANNEL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "Template not found: ${TEMPLATE_PATH}" >&2
  exit 1
fi

if [[ "${CHANNEL}" != "stable" && "${CHANNEL}" != "beta" ]]; then
  echo "Unsupported channel: ${CHANNEL}" >&2
  exit 1
fi

if command -v openssl >/dev/null 2>&1; then
  TOKEN="$(openssl rand -hex 24)"
else
  TOKEN="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi

if [[ -z "${TOKEN}" ]]; then
  echo "Failed to generate gateway token." >&2
  exit 1
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "::add-mask::${TOKEN}"
fi

CURRENT_TEST_INDEX="$(grep -Eo '/mnt/user/appdata/openclaw-cuda/test[0-9]+' "${TEMPLATE_PATH}" | head -n1 | sed -E 's|.*/test([0-9]+)$|\1|' || true)"
if [[ -z "${CURRENT_TEST_INDEX}" ]]; then
  NEXT_TEST_INDEX=4
else
  NEXT_TEST_INDEX=$((CURRENT_TEST_INDEX + 1))
fi

NEXT_BASE_PATH="/mnt/user/appdata/openclaw-cuda/test${NEXT_TEST_INDEX}"
NEXT_WORKSPACE_PATH="${NEXT_BASE_PATH}/workspace"
NEXT_TS_STATE_PATH="${NEXT_BASE_PATH}/tailscale-state"

REPO_BASE="$(sed -n 's|.*<Repository>\(.*\):[^<]*</Repository>.*|\1|p' "${TEMPLATE_PATH}" | head -n1)"
if [[ -z "${REPO_BASE}" ]]; then
  echo "Could not parse repository from ${TEMPLATE_PATH}" >&2
  exit 1
fi
NEXT_REPO="${REPO_BASE}:${CHANNEL}"

perl -0777 -i -pe 's|<Repository>[^<]+</Repository>|<Repository>'"${NEXT_REPO}"'</Repository>|g' "${TEMPLATE_PATH}"
perl -0777 -i -pe 's|<ExtraParams>[^<]*</ExtraParams>|<ExtraParams>--pull always --gpus all --shm-size=2g --restart unless-stopped</ExtraParams>|g' "${TEMPLATE_PATH}"

perl -i -pe 's|<Config Name="OpenClaw Config"[^\n]*</Config>|<Config Name="OpenClaw Config" Target="/home/node/.openclaw" Default="'"${NEXT_BASE_PATH}"'" Mode="rw" Description="Persistent OpenClaw configuration and session data" Type="Path" Display="always" Required="true" Mask="false">'"${NEXT_BASE_PATH}"'</Config>|' "${TEMPLATE_PATH}"
perl -i -pe 's|<Config Name="OpenClaw Workspace"[^\n]*</Config>|<Config Name="OpenClaw Workspace" Target="/home/node/.openclaw/workspace" Default="'"${NEXT_WORKSPACE_PATH}"'" Mode="rw" Description="Workspace for files, memory, and projects managed by OpenClaw" Type="Path" Display="always" Required="true" Mask="false">'"${NEXT_WORKSPACE_PATH}"'</Config>|' "${TEMPLATE_PATH}"
perl -i -pe 's|<Config Name="Gateway Token"[^\n]*</Config>|<Config Name="Gateway Token" Target="OPENCLAW_GATEWAY_TOKEN" Default="'"${TOKEN}"'" Mode="" Description="Required authentication token for UI/API access. Example: openssl rand -hex 24" Type="Variable" Display="always" Required="true" Mask="true">'"${TOKEN}"'</Config>|' "${TEMPLATE_PATH}"
perl -i -pe 's|<TailscaleStateDir\\s*/>|<TailscaleStateDir>'"${NEXT_TS_STATE_PATH}"'</TailscaleStateDir>|g' "${TEMPLATE_PATH}"
perl -i -pe 's|<TailscaleStateDir>[^<]*</TailscaleStateDir>|<TailscaleStateDir>'"${NEXT_TS_STATE_PATH}"'</TailscaleStateDir>|g' "${TEMPLATE_PATH}"

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "${TEMPLATE_PATH}"
fi

echo "template_path=${TEMPLATE_PATH}"
echo "channel=${CHANNEL}"
echo "next_test_index=${NEXT_TEST_INDEX}"
echo "next_base_path=${NEXT_BASE_PATH}"
echo "next_workspace_path=${NEXT_WORKSPACE_PATH}"
echo "next_tailscale_state_path=${NEXT_TS_STATE_PATH}"
