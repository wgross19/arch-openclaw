# GitHub CLI Feature Spec (Baked Runtime - Core Profile)

## Summary
Bake `gh` into `runtime-core` and `runtime-power` to support high-value GitHub workflow skills without manual install steps.

## Problem Statement and User Outcome
OpenClaw GitHub-related skills frequently require `gh`; users should not need to bootstrap it manually in a persistent container.

## Why Baked vs Runtime/Manual Install
Keeps GitHub workflow tooling durable and avoids permission drift.

## Supported Platforms/Architectures
- `linux/amd64`

## Upstream Source of Truth
- GitHub CLI releases (`cli/cli`)
- Pinned artifact: `gh_<version>_linux_amd64.tar.gz`

## Version Pinning Strategy
- Pin version, URL, and SHA256 via Docker `ARG`

## Integrity Verification
- SHA256 verified during build (`GH_SHA256_AMD64`)

## Runtime Path and Invocation Contract
- `gh` available at `/usr/local/bin/gh`
- `gh --version` succeeds as root and `node`

## Filesystem Behavior
- No required cache mounts

## Security Impact / Trivy Expectations
- Adds a single CLI binary
- Minimal Trivy delta expected

## Image Size Impact and Acceptable Delta
- Small increase; acceptable in `core`

## Compatibility Impact
- Additive only; no runtime path or config contract changes

## Debugging Plan
- `gh --version`
- `command -v gh`
- `gosu node:node gh --version`

## Test Plan and Acceptance Criteria
- Contract test asserts gh pin/checksum args and copy/install steps
- Smoke test verifies `gh --version`

## Rollback Plan
- Remove gh artifact fetch/copy and related test assertions
