# Binary Feature Process

## Purpose
Use this process when adding a new baked binary (CLI/tool/runtime helper) to the `arch-openclaw` image. The goal is to keep feature delivery repeatable, secure, and compatible with OpenClaw, Unraid, and the existing CI/release pipeline.

## Release Alignment
- Source tags: `v<openclaw-ref>-rN` (example: `v2026.2.19-r1`)
- Image tags: `<openclaw-ref>-cuda13.1-beta`, `<openclaw-ref>-cuda13.1-rN`

## Required Workflow

### 1. Feature Spec (before implementation)
Create a feature spec in `docs/features/<feature>.md` and get approval before code changes.

Required sections:
- Problem statement and user outcome
- Why the binary is baked vs runtime/manual install
- Supported platforms/architectures
- Upstream source of truth (artifact/release channel)
- Version pinning strategy
- Integrity verification (SHA256/signature)
- Runtime path and invocation contract (`<binary> --version`)
- Filesystem behavior (cache dirs, mounts, writes)
- Security impact / Trivy expectations
- Image size impact and acceptable delta
- Compatibility impact (OpenClaw, Unraid, CUDA, PUID/PGID remap)
- Debugging plan
- Test plan and acceptance criteria
- Rollback plan

Rule: no implementation PR starts before this spec is approved.

### 2. Source Selection Policy (hybrid)
Preferred order:
1. Direct upstream release artifact with pinned version + SHA256
2. Direct artifact with signature verification (if available)
3. Homebrew/tap install in a builder stage with pinned ref/version, then copy runtime artifacts
4. Homebrew in final image (last resort; explicit justification required)

If the selected source is not a direct release artifact, the spec must explain why.

### 3. Implementation Standards (Docker image)
- Pin versions via `ARG`
- Pin source integrity (SHA256 minimum)
- Use builder stage(s) when build tooling is required
- Keep final runtime image minimal
- Install runtime binary to a stable PATH location (prefer `/usr/local/bin`)
- Verify install at build-time with `<binary> --version`
- Preserve non-root runtime behavior (`node` / remapped `PUID:PGID`)
- Reuse existing cache/mount paths where possible

### 4. Debugging Checklist

#### Build-time
- Verify source URL/version resolves correctly
- Verify checksum mismatch fails the build
- Verify extracted package/binary layout
- Verify architecture assumptions (for native binaries)

#### Runtime (container)
- `<binary> --version`
- `<binary> --help`
- PATH lookup (`command -v <binary>`)
- Cache/path write test as app user (`node` / remapped UID:GID)

#### Unraid
- No regressions in startup logs (OpenClaw/Tailscale flow)
- Binary works from Unraid console with `gosu node:node`
- Writes stay in expected mounted paths

#### CI
- Review contract vs smoke vs Trivy failures separately
- Prefer fixing source/dependencies before adding Trivy exceptions
- If exception is required, add time-bounded entries in `.trivyignore.yaml` and sync `.trivyignore`

### 5. PR Requirements
Branch naming:
- `feat/<feature-name>`
- `fix/<feature-name>-<issue>`

PR must include:
- Link to approved feature spec
- Dockerfile diff summary (source pin/checksum)
- Local test evidence (contract/smoke where possible)
- Image size delta summary
- Trivy delta summary
- Unraid validation notes
- Rollback note

Review checklist:
- Source integrity pin present
- Non-root runtime preserved
- Final image does not include unnecessary build tooling
- Contract/smoke tests updated
- Trivy result acceptable (or documented exception)
- Docs/release impact captured

### 6. Release and Rollout
- Merge to `main`
- Publish/validate beta image (`<openclaw-ref>-cuda13.1-beta`)
- Validate on Unraid
- Cut stable source tag `v<openclaw-ref>-rN`
- Publish stable image (`<openclaw-ref>-cuda13.1-rN`)

Watcher note:
- Upstream OpenClaw watcher remains unchanged; binary features are inherited unless compatibility checks fail.
