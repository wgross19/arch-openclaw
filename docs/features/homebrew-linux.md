# Homebrew (Linuxbrew) Feature Spec (Baked Runtime - Power Profile)

## Summary
Provide a baked Linuxbrew runtime in the optional `runtime-power` image under `/home/linuxbrew/.linuxbrew` for broad OpenClaw skill install compatibility.

## Problem Statement and User Outcome
OpenClaw skill install metadata is heavily Homebrew-oriented. Baking Linuxbrew in the power profile dramatically reduces setup friction for advanced users without inflating the default core image.

## Why Baked vs Runtime/Manual Install
Runtime installation is slow, non-durable, and prone to permission issues in Unraid container workflows.

## Supported Platforms/Architectures
- `linux/amd64` (`runtime-power` only)

## Upstream Source of Truth
- `Homebrew/brew` git repository tarball
- Pinned commit + tarball SHA256 in Docker `ARG`s

## Version Pinning Strategy
- Pin brew repo commit and tarball SHA256
- Do not auto-update in container (`HOMEBREW_NO_AUTO_UPDATE=1`)

## Integrity Verification
- Verify Homebrew tarball SHA256 during build
- See `docs/adr/0001-homebrew-brew-archive-checksum-drift.md` for GitHub tarball checksum drift handling.

## Runtime Path and Invocation Contract
- `brew` available via `/home/linuxbrew/.linuxbrew/bin/brew`
- `brew --version` succeeds as `node`

## Filesystem Behavior
- Prefix path: `/home/linuxbrew/.linuxbrew`
- Persistable via existing advanced mount `/home/linuxbrew/.linuxbrew`

## Security Impact / Trivy Expectations
- Increases runtime surface due additional scripting/runtime tooling
- Power-profile-only to isolate core-image risk

## Image Size Impact and Acceptable Delta
- Moderate increase in power profile
- Not acceptable for core profile by default

## Compatibility Impact
- OpenClaw: additive only
- Unraid: no required schema changes (existing Homebrew mount already present)
- CUDA/PUID/PGID: no intended impact beyond ownership handling already in entrypoint

## Debugging Plan
- `brew --version`
- `command -v brew`
- `gosu node:node brew --version`

## Test Plan and Acceptance Criteria
- Contract test asserts Homebrew env + tarball pin/checksum args in Dockerfile
- Power smoke test verifies `brew --version` and writable prefix path

## Rollback Plan
- Remove Homebrew install steps from `runtime-power`; keep mount path optional in templates/docs
