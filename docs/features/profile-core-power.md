# Core + Power Profile Split Feature Spec

## Summary
Split the image into two runtime profiles built from a shared Dockerfile and shared OpenClaw/CUDA/QMD build path:
- `runtime-core` (default)
- `runtime-power` (optional advanced tooling)

## Problem Statement and User Outcome
Users need better out-of-box skill tooling, but baking all tooling into the default image increases image size, Trivy findings, and operational risk for all users.

## Why Split Profiles
A profile split preserves the hardened default while offering a high-capability image for advanced OpenClaw skill workflows.

## Supported Platforms/Architectures
- `linux/amd64`

## Source of Truth and Tagging
- Shared `Dockerfile.unraid-cuda`
- Core tags remain existing defaults (`beta`, `stable`, `<openclaw-ref>-cuda13.1-*`)
- Power tags use `power-*` aliases and `-power-` version tags

## Version Pinning Strategy
- Shared OpenClaw pin via `.openclaw-ref`
- Profile-specific tooling pins live in Dockerfile `ARG`s

## Integrity Verification
- Shared contract tests assert stage structure and tooling pin/checksum markers

## Runtime Contract
- Both profiles keep identical app startup, ports, env contract, and core mounts
- Power adds Homebrew + Playwright/Chromium runtime capability and optional cache mount

## Filesystem Behavior
- Shared config/workspace contract unchanged
- Shared advanced mounts: qmd cache, bun path, homebrew path
- Power-only additional optional mount: Playwright cache path

## Security Impact / Trivy
- Core remains the compatibility/security-first default
- Power isolates heavier dependencies and scan deltas

## Image Size Impact and Acceptable Delta
- Core: moderate growth (tooling additions)
- Power: large growth acceptable for optional advanced profile

## Compatibility Impact
- Existing core users remain on same tag semantics and template path
- Users can switch to power template without data migration (same config/workspace mounts)

## Debugging Plan
- Build/test both `runtime-core` and `runtime-power`
- Validate tag generation and template updates for both profiles

## Test Plan and Acceptance Criteria
- CI matrix builds/tests/scans both profiles
- Contract tests assert profile stages and power template presence
- Smoke tests pass for both profiles with profile-specific checks

## Rollback Plan
- Remove `runtime-power` target, power tags, and power template while retaining core image behavior
