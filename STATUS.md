# Project Status: OpenClaw Unraid CUDA

## Snapshot
- Date: 2026-02-20
- Current milestone: M4 (Beta Burn-In)
- Overall status: On track

## Completed This Period
- Created repository scaffold for image, template, docs, CI, and tests.
- Implemented initial hardened CUDA Docker artifacts.
- Implemented initial CA template with bridge-network defaults and no in-container Tailscale.
- Added migration script baseline and documentation set.
- Applied Dockerfile hardening pass: split build/runtime dependencies and switched source fetch to pinned release tarball.
- Pinned upstream OpenClaw reference to `v2026.2.17` in `.openclaw-ref`.
- Completed local validation build/test cycle against `v2026.2.17` including runtime startup checks.
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
- Tagged repo with `v2026.2.17` (aligned with OpenClaw base ref) and removed prior `v2026` tag.

## In Progress
- Beta channel publish evidence capture (CI artifacts + release notes + checklist closure).

## Blockers
- None currently.

## Active Risks
1. Upstream OpenClaw build assumptions may drift by tag.
   - Mitigation: enforce explicit `OPENCLAW_REF` and beta soak.
2. Host NVIDIA driver compatibility variance.
   - Mitigation: publish compatibility table and troubleshooting steps.

## Decisions
1. 2026-02-19: v1 uses host-level Tailscale only.
2. 2026-02-19: default runtime is non-root with bridge networking.
3. 2026-02-19: CUDA baseline pinned to 12.2.
4. 2026-02-19: Upstream OpenClaw build pin set to `v2026.2.17`.
5. 2026-02-20: Template default appdata contract normalized to `/mnt/user/appdata/openclaw-cuda` (no rotating `testN` defaults for operator installs).

## Next Actions
1. Finalize CI pipeline for build/test/scan/publish.
2. Run/verify beta publish workflow for `OPENCLAW_REF=v2026.2.17` and capture Trivy + smoke evidence.
3. Complete `docs/ca-submission-checklist.md` and stable gate prerequisites.

## Deferred Feature Requests (Post-Baseline)
1. Optional skill dependency preconfiguration for seamless first-run onboarding.
   - Goal: reduce/manual eliminate `bun` and Homebrew installer friction during `openclaw onboard`.
   - Scope: evaluate safe, optional preload paths for common skill installers without weakening container hardening defaults.
   - Timing: after baseline stability/debug milestones are complete and committed.
