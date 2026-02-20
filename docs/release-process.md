# Release and CA Submission Process

## Channels and Tagging
- `beta`: pre-CA validation channel.
- `stable`: production channel after stable gate.
- Git release tags (source): `v<openclaw-ref>-rN` (example: `v2026.2.17-r1`).
- Immutable image tags: `<openclaw-ref>-cuda13.1-rN` (stable) and `<openclaw-ref>-cuda13.1-beta` (beta candidate).
- Immutable source traceability tag: `sha-<git-sha>`.

## Workflow Triggers
- Pull requests: run validation and contract tests.
- Push to `main` with `.openclaw-ref` changes: build, scan, and publish `beta`.
- Git tags (`v*-r*`): build, scan, and publish stable artifacts.
- Manual dispatch: build/publish beta or stable candidate for selected OpenClaw tag/revision.
- Scheduled upstream watcher (`watch-openclaw-releases`): opens a PR when OpenClaw publishes a newer stable release.

## Build Process
1. Resolve OpenClaw upstream tag (`OPENCLAW_REF`) from workflow input.
2. Build image with pinned CUDA base and Node/pnpm versions.
3. Stamp OCI labels (source, revision, created date, upstream ref).

## Test Process
1. Run contract tests for XML and scripts.
2. Build container image and run startup smoke check with required token.
3. Validate no legacy runtime bootstrap behavior remains.

## Security Scan Process
1. Scan image with Trivy in CI.
2. Fail release pipeline on `CRITICAL,HIGH` vulnerabilities (excluding documented exceptions in `.trivyignore.yaml`, enforced at scan-time through `.trivyignore`).
3. Keep every Trivy exception time-bounded (`expired_at`) and justified (`statement`), and keep `.trivyignore` synchronized, enforced by `scripts/validate-trivy-ignore.sh` in CI.
4. Attach scan summary to workflow artifacts.

## Publish Process
- Beta:
  - Triggered when `.openclaw-ref` changes on `main` (for example, merge of watcher PR), or manually dispatched.
  - Push `beta`, `sha-*`, and versioned `*-cuda13.1-beta` tag.
- Stable:
  - Triggered by git tag `v<openclaw-ref>-rN` after beta soak criteria are satisfied.
  - Tag parser derives `openclaw_ref` and `rN`, verifies `.openclaw-ref` matches, then publishes:
    - `stable`
    - `sha-*`
    - `<openclaw-ref>-cuda13.1-rN`

## Release Notes Template
Each release note must include:
1. Upstream OpenClaw tag and git commit.
2. CUDA baseline and known driver compatibility notes.
3. Migration impact summary (if any).
4. Added/changed/removed contract items.
5. Known issues and workarounds.

## Beta Gate Checklist
- [ ] Required QA scenarios pass in E1 and E3.
- [ ] Migration + rollback validated.
- [ ] No P0 defects open.
- [ ] Template URL install flow verified.

## Stable Gate Checklist
- [ ] Beta soak period completed.
- [ ] Required QA scenarios pass in E1, E2, E3.
- [ ] No P0/P1 defects open.
- [ ] Docs updated for final image tags.
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
