# Playwright + Chromium Feature Spec (Power Profile)

## Summary
Bake Playwright browser support (Chromium binaries + cache path conventions) into the optional `runtime-power` image to improve OpenClaw browser-tool readiness in Docker/Unraid deployments.

## Problem Statement and User Outcome
OpenClaw browser features require Playwright for many actions. The default Docker experience intentionally omits bundled browsers, creating setup friction.

## Why Baked vs Runtime/Manual Install
Runtime browser downloads are slow, non-durable, and easy to misconfigure. Baking them in the power profile improves repeatability.

## Supported Platforms/Architectures
- `linux/amd64` (`runtime-power`)

## Upstream Source of Truth
- Playwright npm package (version aligned with OpenClaw `v2026.2.23` dependency: `1.58.2`)
- Chromium downloaded via Playwright CLI during image build

## Version Pinning Strategy
- Pin `PLAYWRIGHT_VERSION` in Dockerfile
- Prefer bundled/local Playwright package from OpenClaw build when present; install pinned package only if absent

## Integrity Verification
- npm version pin for Playwright package
- Chromium install handled by Playwright CLI (no separate checksum pin in this feature)

## Runtime Path and Invocation Contract
- `PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright`
- Power image contains Chromium browser binaries under that cache path
- Playwright CLI version check succeeds during build

## Filesystem Behavior
- Browser cache path: `/home/node/.cache/ms-playwright`
- New optional advanced mount added to power Unraid template for persistence

## Security Impact / Trivy Expectations
- Significant image size and dependency increase (browser runtime + libs)
- Power-profile-only to isolate core image attack surface and scan noise

## Image Size Impact and Acceptable Delta
- Large increase; acceptable only in `runtime-power`

## Compatibility Impact
- OpenClaw: additive only (no source patching)
- Unraid: new optional mount in power template only
- CUDA/PUID/PGID: no intended impact

## Debugging Plan
- Verify `PLAYWRIGHT_BROWSERS_PATH`
- Verify Chromium files exist in cache path
- Run a browser-tool smoke/manual check on Unraid power profile

## Test Plan and Acceptance Criteria
- Contract test asserts Playwright env/install markers in Dockerfile
- Power smoke test verifies cache path, env, and Chromium file presence

## Rollback Plan
- Remove Playwright install/browser download steps and revert power template cache mount
