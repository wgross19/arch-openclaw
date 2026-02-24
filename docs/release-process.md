# Release and CA Submission Process

## Channels and Tagging
- `beta`: pre-CA validation channel.
- `stable`: production channel after stable gate.
- Git release tags (source): `v<openclaw-ref>-rN` (example: `v2026.2.23-r1`).
- Core image immutable tags: `<openclaw-ref>-cuda13.1-rN` (stable) and `<openclaw-ref>-cuda13.1-beta` (beta candidate).
- Power image immutable tags: `<openclaw-ref>-cuda13.1-power-rN` (stable) and `<openclaw-ref>-cuda13.1-power-beta` (beta candidate).
- Channel aliases:
  - Core: `beta`, `stable`
  - Power: `power-beta`, `power-stable`, `power` (stable alias)
- Immutable source traceability tags: `sha-<git-sha>` (core) and `sha-<git-sha>-power`.

## Workflow Triggers
- Pull requests: run validation and contract tests.
- Push to `main` with `.openclaw-ref` changes: build, scan, and publish `beta`.
- Git tags (`v*-r*`): build, scan, and publish stable artifacts.
- Manual dispatch: build/publish beta or stable candidate for selected OpenClaw tag/revision.
- Scheduled upstream watcher (`watch-openclaw-releases`): opens a PR when OpenClaw publishes a newer stable release.

## Build Process
1. Resolve OpenClaw upstream tag (`OPENCLAW_REF`) from workflow input.
2. Build `runtime-core` and `runtime-power` images from the shared Dockerfile with pinned CUDA base and Node/pnpm versions.
3. Stamp OCI labels (source, revision, created date, upstream ref).

## Test Process
1. Run contract tests for XML and scripts.
2. Build both profiles and run startup smoke checks with required token.
3. Validate no legacy runtime bootstrap behavior remains.

## Security Scan Process
1. Scan core and power images with Trivy in CI.
2. Fail release pipeline on `CRITICAL,HIGH` vulnerabilities (excluding documented exceptions in `.trivyignore.yaml`, enforced at scan-time through `.trivyignore`).
3. Keep every Trivy exception time-bounded (`expired_at`) and justified (`statement`), and keep `.trivyignore` synchronized, enforced by `scripts/validate-trivy-ignore.sh` in CI.
4. Attach scan summary to workflow artifacts.

## Publish Process
- Beta:
  - Triggered when `.openclaw-ref` changes on `main` (for example, merge of watcher PR), or manually dispatched.
  - Publish both profiles:
    - Core: `beta`, `sha-*`, `<openclaw-ref>-cuda13.1-beta`
    - Power: `power-beta`, `sha-*-power`, `<openclaw-ref>-cuda13.1-power-beta`
- Stable:
  - Triggered by git tag `v<openclaw-ref>-rN` after beta soak criteria are satisfied.
  - Tag parser derives `openclaw_ref` and `rN`, verifies `.openclaw-ref` matches, then publishes:
    - Core: `stable`, `sha-*`, `<openclaw-ref>-cuda13.1-rN`
    - Power: `power`, `power-stable`, `sha-*-power`, `<openclaw-ref>-cuda13.1-power-rN`
  - Update both Unraid templates (`core` and `power`) in the publish workflow.

## Release Notes Template
Each release note must include:
1. Upstream OpenClaw tag and git commit.
2. CUDA baseline and known driver compatibility notes.
3. Migration impact summary (if any).
4. Added/changed/removed contract items.
5. Known issues and workarounds.
6. Baked binary validation evidence (version/path/permissions) for any newly added image binaries.
7. Profile-specific validation notes (`core` vs `power`) and image digests.

## Beta Gate Checklist
- [ ] Required QA scenarios pass in E1 and E3.
- [ ] Migration + rollback validated.
- [ ] Newly added baked binary features validated on Unraid (command works, PATH correct, cache path writable).
- [ ] Core and power templates updated and validated for the release channel.
- [ ] No P0 defects open.
- [ ] Template URL install flow verified.

## Stable Gate Checklist
- [ ] Beta soak period completed.
- [ ] Required QA scenarios pass in E1, E2, E3.
- [ ] No P0/P1 defects open.
- [ ] Docs updated for final image tags.
- [ ] Power profile release tags/template validated (if publishing power profile).
- [ ] CA submission checklist complete.

## CA Submission Checklist
- [ ] XML imports cleanly in Unraid template editor.
- [ ] No hardcoded secrets or test values.
- [ ] Support/project/readme links valid.
- [ ] WebUI and port settings verified.
- [ ] Required and optional fields documented.
- [ ] GPU settings validated on supported host.
- [ ] `docs/ca-submission-checklist.md` reviewed and checked off.

## Post-Submission Monitoring
Track for first 30 days:
- Install success/failure trend.
- Top issue categories (permissions, GPU, networking).
- Mean time to first response on support issues.
- Patch release cadence and defect escape rate.
