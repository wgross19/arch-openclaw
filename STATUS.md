# Project Status: OpenClaw Unraid CUDA

## Snapshot
- Date: 2026-02-19
- Current milestone: M0 (Scaffold and Architecture Lock)
- Overall status: On track

## Completed This Period
- Created repository scaffold for image, template, docs, CI, and tests.
- Implemented initial hardened CUDA Docker artifacts.
- Implemented initial CA template with bridge-network defaults and no in-container Tailscale.
- Added migration script baseline and documentation set.
- Applied Dockerfile hardening pass: split build/runtime dependencies and switched source fetch to pinned release tarball.
- Pinned upstream OpenClaw reference to `v2026.2.17` in `.openclaw-ref`.

## In Progress
- Contract validation scripts and CI workflow hardening.
- Final verification pass for migration and template assumptions.

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

## Next Actions
1. Finalize CI pipeline for build/test/scan/publish.
2. Add automated contract tests for XML and migration script.
3. Produce initial beta release candidate checklist.
