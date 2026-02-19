# Project Tracking Model

## Milestones and Exit Criteria

### M0: Scaffold and Architecture Lock (Days 1-3)
- Exit criteria:
  - `docs/architecture.md` approved.
  - Core repo structure created.
  - Tracking board and labels initialized.

### M1: Hardened Image MVP (Week 1-2)
- Exit criteria:
  - `Dockerfile.unraid-cuda`, entrypoint, healthcheck complete.
  - Non-root startup defaults validated.
  - Runtime installers removed.

### M2: Template and Migration (Week 2-3)
- Exit criteria:
  - CA XML template complete.
  - Migration script + guide complete.
  - Contract tests for template and script pass.

### M3: CI/CD and Validation Harness (Week 3-4)
- Exit criteria:
  - Build/test/release workflow active.
  - QA plan scenarios automated where feasible.
  - Security scan gating enabled.

### M4: Beta Burn-In (Week 4-5)
- Exit criteria:
  - Beta images published and install-tested.
  - Critical defects triaged and fixed.
  - Beta feedback loop operational.

### M5: Stable and CA Submission (Week 5-6)
- Exit criteria:
  - Stable gate criteria met.
  - CA checklist complete.
  - Stable template submitted.

## Board Workflow
Use GitHub Projects with columns:
- `Backlog`
- `Ready`
- `In Progress`
- `Blocked`
- `In Review`
- `Done`

WIP policy:
- Max 2 active items per contributor.
- Any card in `Blocked` > 48h must include mitigation owner + ETA.

## Issue Taxonomy
Required labels:
- `phase/m0` ... `phase/m5`
- `type/feature`, `type/bug`, `type/chore`, `type/docs`
- `risk/security`, `risk/compat`, `risk/release`
- `blocked`
- `release/beta`, `release/stable`

## Required Issue Fields
Each implementation issue must include:
1. Milestone
2. Owner
3. Size estimate
4. Acceptance criteria
5. Dependency links

## Reporting Cadence
- Update `STATUS.md` twice weekly.
- Groom board at least once per week.
- Add decision log entry for each contract-changing decision.

## KPI Targets
- CI build pass rate >= 95%.
- Required test pass rate = 100% at release gates.
- Open P0/P1 defects = 0 before stable release.
- Blockers older than 48h = 0.

## Decision Log Format
Use this structure in status updates:
- `Date`
- `Decision`
- `Context`
- `Impact`
- `Owner`

## Risk Burndown
Track active risks with:
- Severity
- Trigger signal
- Current mitigation
- Due date
- Residual risk after mitigation
