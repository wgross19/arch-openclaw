# Python + uv Feature Spec (Baked Runtime - Core Profile)

## Summary
Bake `python3`, `uv`, and `uvx` into `runtime-core` and `runtime-power` to unlock high-value image/PDF skills that depend on Python and uv-based execution.

## Problem Statement and User Outcome
Several OpenClaw skills require `python3` or `uv`; installing them manually is a common friction point.

## Why Baked vs Runtime/Manual Install
Improves first-run skill eligibility and avoids in-container drift.

## Supported Platforms/Architectures
- `linux/amd64`

## Upstream Source of Truth
- `python3`: Ubuntu apt repo in pinned CUDA/Ubuntu base image
- `uv`: Astral `uv` GitHub Releases (`uv-x86_64-unknown-linux-gnu.tar.gz`)

## Version Pinning Strategy
- `python3` version tracks Ubuntu base image package repo
- `uv` pinned by version, URL, and SHA256 via Docker `ARG`

## Integrity Verification
- `uv` SHA256 verified during build
- apt signature verification for `python3`

## Runtime Path and Invocation Contract
- `python3`, `uv`, `uvx` on PATH
- `python3 --version`, `uv --version` succeed as root and `node`

## Filesystem Behavior
- Skill-specific caches remain under normal user home paths (no new mandatory mounts)

## Security Impact / Trivy Expectations
- `python3` adds runtime libs; Trivy delta expected
- `uv` adds a single binary

## Image Size Impact and Acceptable Delta
- Moderate increase due Python runtime; acceptable in `core` for skill coverage

## Compatibility Impact
- OpenClaw: additive only
- Unraid/CUDA/PUID/PGID: no intended impact

## Debugging Plan
- `python3 --version`
- `uv --version`
- `command -v uvx`

## Test Plan and Acceptance Criteria
- Contract test asserts uv pin/checksum args and copy/install steps
- Smoke test verifies `python3`, `uv` execute

## Rollback Plan
- Remove `python3`/uv steps and related test assertions
