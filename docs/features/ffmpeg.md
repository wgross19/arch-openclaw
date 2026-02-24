# FFmpeg Feature Spec (Baked Runtime - Core Profile)

## Summary
Bake `ffmpeg`/`ffprobe` into `runtime-core` and `runtime-power` to enable high-impact media and channel features (notably Discord voice-message processing).

## Problem Statement and User Outcome
OpenClaw channel/media workflows require `ffmpeg`/`ffprobe`; asking users to install them manually in-container is non-durable.

## Why Baked vs Runtime/Manual Install
Persistent and reproducible media capability with no runtime package installs.

## Supported Platforms/Architectures
- `linux/amd64` (image line target)

## Upstream Source of Truth
- Ubuntu 22.04 apt repositories in the CUDA base image environment
- Package: `ffmpeg` (provides `ffprobe`)

## Version Pinning Strategy
- Inherit Ubuntu package version from the pinned CUDA/Ubuntu base image
- Re-validate on base image bumps

## Integrity Verification
- APT signature verification through distro repositories (no direct artifact SHA in this feature)

## Runtime Path and Invocation Contract
- `ffmpeg` and `ffprobe` on PATH
- `ffmpeg -version`, `ffprobe -version` succeed

## Filesystem Behavior
- No special cache path required by default

## Security Impact / Trivy Expectations
- Adds multimedia libraries and codecs; Trivy delta expected and must be reviewed

## Image Size Impact and Acceptable Delta
- Moderate increase; acceptable in `core` due broad feature unlock

## Compatibility Impact
- OpenClaw: additive only
- Unraid: no contract changes required
- CUDA/PUID/PGID: no intended impact

## Debugging Plan
- `ffmpeg -version`
- `ffprobe -version`
- basic local transcode/read test in manual validation

## Test Plan and Acceptance Criteria
- Contract test asserts `ffmpeg` install in core stage
- Smoke test verifies both binaries execute

## Rollback Plan
- Remove `ffmpeg` package and related smoke/contract checks
