# Release and CA Submission Process

## Channels and Tagging
- `beta`: pre-CA validation channel.
- `stable`: production channel after stable gate.
- Immutable version tags: `<openclaw-tag>-cuda12.2`.
- Immutable source traceability tag: `sha-<git-sha>`.

## Workflow Triggers
- Pull requests: run validation and contract tests.
- Git tags (`v*`): build, scan, and publish stable artifacts.
- Manual dispatch: build/publish beta candidate for selected OpenClaw tag.

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
2. Fail release pipeline on `CRITICAL,HIGH` vulnerabilities (excluding documented exceptions).
3. Attach scan summary to workflow artifacts.

## Publish Process
- Beta:
  - Manual dispatch with `channel=beta` and selected `OPENCLAW_REF`.
  - Push `beta`, `sha-*`, and versioned `*-cuda12.2` tags.
- Stable:
  - Triggered by release tag after beta soak criteria are satisfied.
  - Push `stable`, `sha-*`, and versioned `*-cuda12.2` tags.

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
