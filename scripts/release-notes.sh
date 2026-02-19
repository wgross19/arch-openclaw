#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <openclaw_ref> <image_name> <output_path>" >&2
  exit 1
fi

OPENCLAW_REF="$1"
IMAGE_NAME="$2"
OUT_PATH="$3"
DATE_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

cat > "${OUT_PATH}" <<NOTES
# Release Notes

## Build Metadata
- Date (UTC): ${DATE_UTC}
- Upstream OpenClaw tag: ${OPENCLAW_REF}
- CUDA baseline: 12.2
- Image repository: ${IMAGE_NAME}

## Contract Summary
- Bridge networking default with explicit UI port mapping.
- Non-root runtime by default.
- Host-level Tailscale integration only.
- No runtime package/bootstrap installers.

## Migration Notes
- Uses /home/node/.openclaw path contract.
- Legacy in-container Tailscale variables removed.
- See docs/migration-v1.md for scripted migration and rollback.

## Validation Checklist
- [ ] Contract tests passed
- [ ] Migration tests passed
- [ ] Smoke container tests passed
- [ ] Trivy scan passed

## Known Issues
- Add any version-specific known issues before publishing a GitHub release.
NOTES
