# ADR 0001: Homebrew Brew Archive Checksum Drift in Power Profile

## Status
Accepted (2026-02-24)

## Context
The `runtime-power` image bakes Linuxbrew/Homebrew to improve OpenClaw skill install compatibility.

The current implementation pins:
- a specific `Homebrew/brew` commit
- the SHA256 of the GitHub-generated archive tarball for that commit

During local validation of the `runtime-power` build on **2026-02-24**, the pinned commit remained the same but the GitHub archive SHA256 changed:
- Commit: `49a172a9e41fe30cc7a1779f25ba604936d42049`
- Old SHA256 (failed): `590977e2d7937b907edc691bfa1527ccd16f4c09923e14126ea76e37ee2f64fd`
- New SHA256 (observed): `a5237ed4a0f874adcdc590e833b5c93c78a0cf6353e5e57f013d347f882a032b`

This indicates the GitHub-generated tarball is not stable enough to treat its checksum as immutable over time, even for the same commit.

## Decision
Keep Homebrew baked in the `power` profile, but explicitly treat GitHub archive checksum drift as an operational risk:

- We continue pinning both commit and tarball SHA256.
- We fail builds on checksum mismatch (do not disable integrity checks).
- When drift occurs, we update the SHA256 after manual verification and document the change.
- The `core` profile remains unchanged and does not depend on Homebrew.

## Consequences
Positive:
- Maintains strong integrity checks instead of silently accepting changed artifacts.
- Limits blast radius to the optional `power` profile.
- Preserves the user-facing Homebrew convenience that materially improves OpenClaw skill support.

Negative:
- `runtime-power` builds may break unexpectedly when GitHub archive output changes.
- Maintenance overhead increases due to occasional checksum refreshes.

## Revisit Criteria
Revisit this decision if any of the following occur:

1. GitHub archive checksum drift happens repeatedly (for example, more than once in a quarter).
2. `runtime-power` CI reliability drops due to Homebrew archive volatility.
3. Security review requires a reproducible artifact source stronger than GitHub-generated tarballs.

## Alternatives to Evaluate on Revisit
1. Fetch `brew` via `git clone --depth=1` at pinned commit and verify commit hash (accepting different trust/reproducibility tradeoffs).
2. Mirror a verified `brew` tarball to a controlled release asset and pin that artifact checksum.
3. Remove baked Homebrew from `runtime-power` and keep path-only support if reproducibility/maintenance cost becomes unacceptable.
