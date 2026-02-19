# Validation and QA Plan

## Test Environment Matrix
| ID | Environment | GPU | Purpose |
|---|---|---|---|
| E1 | Unraid 6.12+ local | NVIDIA enabled | Full functional + GPU path |
| E2 | Unraid 6.12+ local | No GPU | CPU fallback behavior |
| E3 | CI docker host | N/A | Contract tests and script validation |

## Functional Scenarios
1. Fresh install with required token and one API key.
2. UI access with tokenized URL.
3. Workspace persistence across container restart.
4. Container recreation with same mounts preserves state.
5. Optional provider keys absent does not break startup.

## Permission Scenarios
1. Default non-root startup can read/write config and workspace mounts.
2. Legacy owner mismatch repaired with one-time root + `PUID`/`PGID` + `OPENCLAW_CHOWN=true`.
3. Restart after ownership repair succeeds in non-root mode.

## GPU Scenarios
1. `nvidia-smi` available in container when GPU is configured.
2. CUDA runtime libs are present without runtime package install.
3. OpenClaw GPU-related workloads run on GPU-enabled host.
4. CPU-only hosts do not crash; workloads degrade gracefully.

## Network and Tailscale Scenarios
1. Bridge mode port map serves UI on `18789`.
2. No in-container `tailscaled` process exists.
3. Access over host Tailscale IP/MagicDNS works when host is configured.

## Upgrade and Migration Scenarios
1. Upgrade from beta tag to stable tag preserves state.
2. Migration script handles legacy appdata layout in-place.
3. Rollback restores pre-migration state archive.

## Negative/Failure Scenarios
1. Missing `OPENCLAW_GATEWAY_TOKEN` fails fast with actionable error.
2. Invalid mount path surfaces clear startup failure.
3. Invalid provider key does not block gateway startup.
4. GPU env present but host GPU unavailable logs clear warning path.

## Release Gates
### Beta Gate
- All E1/E3 required scenarios pass.
- No P0 defects open.
- Migration + rollback tested at least once.

### Stable Gate
- All required scenarios pass in E1/E2/E3.
- No P0/P1 defects open.
- Documentation and template contract tests pass.

## Test Artifacts
- `tests/test-contract.sh`
- `tests/test-migration-script.sh`
- CI workflow logs and image digest outputs
