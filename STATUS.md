# Project Status: OpenClaw Unraid CUDA

## Snapshot
- Date: 2026-02-24
- Current milestone: M4 (Beta Burn-In)
- Overall status: On track

## Completed This Period
- Created repository scaffold for image, template, docs, CI, and tests.
- Implemented initial hardened CUDA Docker artifacts.
- Implemented initial CA template with bridge-network defaults and no in-container Tailscale.
- Added migration script baseline and documentation set.
- Applied Dockerfile hardening pass: split build/runtime dependencies and switched source fetch to pinned release tarball.
- Pinned upstream OpenClaw reference to `v2026.2.23` in `.openclaw-ref`.
- Implemented core/power runtime profile split in `Dockerfile.unraid-cuda` with shared build path and backward-compatible core alias target.
- Added power Unraid template (`templates/openclaw-unraid-cuda-power.xml`) and CI profile matrix build/test/scan/publish plumbing.
- Added baked high-impact tooling plan implementation (core: Bun/ffmpeg/core CLIs/python3/uv/gh; power: Homebrew + Playwright/Chromium support).
- Fixed validation findings: architecture-aware Node tarball selection, pinned pnpm install path, CI-safe non-interactive builds, and gateway bind-mode compatibility (`OPENCLAW_GATEWAY_BIND=lan` default).
- Completed Unraid host validation on appdata `/mnt/user/appdata/openclaw-cuda/test8`.
- Verified permission repair workflow and successful `openclaw onboard` launch.
- Resolved Control UI auth/pairing flow (`token_missing` and `pairing required`) and confirmed pairing persists across restart.
- Verified GPU/runtime health in container (`nvidia-smi` passes and CUDA runtime libs are present via `ldconfig`/filesystem checks).
- Updated Unraid template defaults:
  - container name `OpenClaw-CUDA`
  - icon `https://cdn.jsdelivr.net/gh/selfhst/icons@main/webp/openclaw.webp`
  - appdata paths `/mnt/user/appdata/openclaw-cuda` + `/workspace`
  - updated workspace description text
  - tailscale state path `/mnt/user/appdata/openclaw-cuda/tailscale-state`
- Unblocked OpenClaw memory runtime prerequisites by pinning Node `22.13.1`, source-building Node with shared system SQLite (`--shared-sqlite`), and adding `node:sqlite` + FTS5 build/smoke validation.
- Tagged repo with `v2026.2.17` (aligned with OpenClaw base ref) and removed prior `v2026` tag.

## In Progress
- Beta channel publish evidence capture (CI artifacts + release notes + checklist closure) for core and power profiles.
- Validation pass for new profile split on local Docker + Unraid hosts.

## Blockers
- None currently.

## Active Risks
1. Upstream OpenClaw build assumptions may drift by tag.
   - Mitigation: enforce explicit `OPENCLAW_REF` and beta soak.
2. Host NVIDIA driver compatibility variance.
   - Mitigation: publish compatibility table and troubleshooting steps.
3. Power profile image size / Trivy delta may increase maintenance overhead.
   - Mitigation: keep core as default/recommended image and isolate heavier tooling to power profile.

## Decisions
1. 2026-02-19: v1 uses host-level Tailscale only.
2. 2026-02-19: default runtime is non-root with bridge networking.
3. 2026-02-19: CUDA baseline pinned to 12.2.
4. 2026-02-24: Upstream OpenClaw build pin updated to `v2026.2.23`.
5. 2026-02-20: Template default appdata contract normalized to `/mnt/user/appdata/openclaw-cuda` (no rotating `testN` defaults for operator installs).
6. 2026-02-24: Ship two image profiles (`core` default, `power` optional) from one Dockerfile/CI pipeline.

## Next Actions
1. Finalize CI pipeline for build/test/scan/publish.
2. Run/verify beta publish workflow for `OPENCLAW_REF=v2026.2.23` and capture Trivy + smoke evidence for core and power.
3. Validate power profile tooling (`brew`, Playwright/Chromium) on Unraid and document findings.
4. Complete `docs/ca-submission-checklist.md` and stable gate prerequisites.

## Feature Follow-Up (Post-Implementation Validation)
1. Review core vs power profile Trivy/image-size tradeoffs after beta soak and adjust tooling placement if needed.
2. Track OpenClaw browser-tool compatibility in power profile and document any Playwright build-specific limitations.
