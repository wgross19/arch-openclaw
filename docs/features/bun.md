# Bun Feature Spec (Baked Runtime - Core Profile)

## Summary
Bake Bun into the `runtime-core` and `runtime-power` images to reduce skill/onboarding friction while keeping the Gateway runtime on Node.

## Problem Statement and User Outcome
Users hit avoidable setup friction when skills or workflows expect `bun`/`bunx` on PATH. After this change, `bun` is available by default and `/home/node/.bun` can be persisted with the existing advanced mount.

## Why Baked vs Runtime/Manual Install
Manual installs inside a running container are not durable and create ownership drift risk on Unraid.

## Supported Platforms/Architectures
- `linux/amd64` for this image line (QMD already constrains the image to amd64)

## Upstream Source of Truth
- Upstream: Bun GitHub Releases (`oven-sh/bun`)
- Pinned version: `1.3.9`
- Artifact: `bun-linux-x64.zip`

## Version Pinning Strategy
- Pin version and artifact URL via Docker `ARG`
- Verify artifact SHA256 during build

## Integrity Verification
- SHA256 pinned in Dockerfile (`BUN_SHA256_AMD64`)

## Runtime Path and Invocation Contract
- `bun` available at `/usr/local/bin/bun`
- `bun --version` succeeds as root and `node`

## Filesystem Behavior
- `BUN_INSTALL=/home/node/.bun`
- Persistable via existing advanced mount `/home/node/.bun`

## Security Impact / Trivy Expectations
- Adds a single runtime binary
- Minimal Trivy impact expected vs package-manager installs in runtime

## Image Size Impact and Acceptable Delta
- Small to moderate increase (single compressed binary)
- Acceptable in `core`

## Compatibility Impact
- OpenClaw: additive only; Gateway still runs on Node
- Unraid: no required template changes (existing Bun mount remains valid)
- CUDA/PUID/PGID: no intended impact

## Debugging Plan
- `bun --version`
- `command -v bun`
- `gosu node:node bun --version`

## Test Plan and Acceptance Criteria
- Contract test asserts Bun pin/checksum args and copy/install steps exist
- Smoke test verifies `bun --version` and Bun path write access

## Rollback Plan
- Revert Bun install/copy steps and related contract/smoke assertions
