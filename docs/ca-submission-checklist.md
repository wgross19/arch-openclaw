# Community Apps Submission Checklist

## Metadata
- [ ] `Name`, `Repository`, `Project`, `Support`, and `Icon` are valid.
- [ ] `TemplateURL` points to raw XML in the main branch.
- [ ] `Overview` text matches current runtime behavior and does not reference in-container Tailscale.

## Security and Secrets
- [ ] No hardcoded API keys or secrets in XML defaults.
- [ ] Default container operation is non-root.
- [ ] No `NET_ADMIN`, privileged mode, or runtime bootstrap commands.

## Runtime Contract
- [ ] Network default is `bridge`.
- [ ] Port `18789` is mapped and documented.
- [ ] Required path mounts map to `/home/node/.openclaw` and `/home/node/.openclaw/workspace`.
- [ ] Required env var `OPENCLAW_GATEWAY_TOKEN` is marked required.

## GPU Contract
- [ ] GPU params use `--gpus all`.
- [ ] NVIDIA env defaults are set and documented.
- [ ] CUDA baseline in docs matches image build (`13.1`).

## Docs and Supportability
- [ ] Install guide updated for current release.
- [ ] Migration guide updated if contract changed.
- [ ] Troubleshooting section covers permissions, GPU, and networking.
- [ ] Release notes include upstream OpenClaw tag and known issues.

## Validation Evidence
- [ ] `tests/test-contract.sh` passed.
- [ ] `tests/test-migration-script.sh` passed.
- [ ] CI image build + Trivy scan passed.
- [ ] Beta soak completed with no open P0/P1 defects.
