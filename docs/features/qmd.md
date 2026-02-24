# QMD Feature Spec (Baked Binary)

## Summary
Bake `qmd` into the default `OpenClaw-CUDA` image so users do not need to manually install it (for example via Homebrew) inside a running container.

## User Outcome
- `qmd` is available on PATH in the shipped image.
- `qmd --version` works in the container as the app user (`node` / remapped `PUID:PGID`).
- qmd cache data persists via the existing advanced mount at `/home/node/.cache/qmd` when configured.

## Why Bake It Into the Image
Manual in-container installation is not durable and creates permission drift risk (especially when using Unraid's root console). Baking qmd into the image keeps installs reproducible and compatible with the existing non-root runtime model.

## Scope / Platform
- qmd v1 support target: `linux/amd64`
- Included in the default `OpenClaw-CUDA` image
- Binary/package only (no cache/model preloading)

## Source of Truth and Pinning
qmd does not currently publish standalone Linux binary assets on GitHub Releases. For v1, this image uses the upstream npm package tarball as the direct pinned artifact.

Pinned values (v1):
- qmd version: `1.0.7`
- Artifact URL: `https://registry.npmjs.org/@tobilu/qmd/-/qmd-1.0.7.tgz`
- SHA256: `c00f6b6b33486faeaecc0b7eb40ce148f2b66d77023527a4541fdefdfc5525e9`
- Upstream repo/tag (reference): `https://github.com/tobi/qmd` / `v1.0.7`

## Install Strategy
- Use a dedicated Docker builder stage (`qmd-builder`)
- Download the pinned qmd npm tarball
- Verify SHA256
- Install qmd globally with npm in the builder stage
- Copy qmd package files into the runtime image
- Create a stable symlink at `/usr/local/bin/qmd`
- Verify with `qmd --version` during image build

Notes:
- qmd upstream currently uses a `bun.lock`, not an npm/pnpm lockfile. The top-level artifact is pinned and hashed, but transitive npm dependency resolution can still drift over time. If this becomes a reproducibility or security issue, move to a stronger source strategy (for example, upstream binary assets or a locked builder workflow).

## Runtime Contract
- `qmd` is on PATH at `/usr/local/bin/qmd`
- `qmd --version` succeeds as `node`
- `qmd --help` succeeds as `node`
- qmd writes cache data under `/home/node/.cache/qmd`

## Filesystem and Mount Behavior
- Cache path: `/home/node/.cache/qmd`
- Existing Unraid template advanced mount can persist qmd cache
- No changes to OpenClaw config/workspace paths

## Security Impact / Trivy
- Adds qmd and its npm dependency tree to the image
- May introduce additional Trivy findings (Node package CVEs)
- Existing Trivy policy remains in force (`.trivyignore.yaml` + `.trivyignore`)
- New exceptions require time-bounded justification and only after evaluating source/dependency alternatives

## Compatibility Impact
### OpenClaw
Additive only. qmd is not on the OpenClaw startup path.

### Unraid
No required template schema changes. Existing advanced qmd cache mount remains valid.

### CUDA
No intended change to CUDA library/runtime behavior. Regression protection remains in smoke and manual validation.

## Debugging Plan
### Container checks
- `qmd --version`
- `qmd --help`
- `command -v qmd`
- cache write test under `/home/node/.cache/qmd`

### Unraid checks
- `gosu node:node qmd --version`
- qmd invocation from the container console after startup
- validate cache writes land in the mounted qmd cache path (if mounted)

## Test Plan / Acceptance Criteria
- Contract test asserts qmd version/url/checksum args and install steps are present in `Dockerfile.unraid-cuda`
- Smoke test verifies:
  - `qmd --version`
  - `command -v qmd`
  - qmd cache path writable as app user
  - existing gateway startup behavior unchanged
- Existing contract/migration/smoke/Trivy/publish workflow remains green

## Rollback Plan
If qmd causes compatibility, security, or image-size regressions:
1. Revert the qmd PR, or
2. Publish the next arch revision (`-rN` bump) without qmd after reverting the feature changes
