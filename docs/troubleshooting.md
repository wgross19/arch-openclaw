# Troubleshooting

## Permission Denied on Startup
Symptoms:
- Startup fails with directory creation/write errors under `/home/node/.openclaw`.

Actions:
1. Confirm host path ownership/permissions on appdata and workspace.
2. For one-time repair, start container as root and set:
   - `PUID=<target uid>`
   - `PGID=<target gid>`
   - `OPENCLAW_CHOWN=true`
3. Restart once with defaults (non-root).

## Gateway Token Required Error
Symptoms:
- Entry fails with `OPENCLAW_GATEWAY_TOKEN is required`.

Actions:
1. Set `OPENCLAW_GATEWAY_TOKEN` in template.
2. Use a high-entropy token (`openssl rand -hex 24`).

## UI Not Reachable
Symptoms:
- Browser cannot open `http://UNRAID-IP:18789`.

Actions:
1. Confirm container is running.
2. Confirm port mapping for `18789/tcp` in bridge mode.
3. Check host firewall/network rules.
4. If using Tailscale, verify host-level reachability to Unraid node.

## GPU Not Visible
Symptoms:
- `nvidia-smi` fails inside container.

Actions:
1. Confirm Unraid NVIDIA plugin is installed and driver loaded on host.
2. Ensure container has `--gpus all`.
3. Verify env vars:
   - `NVIDIA_VISIBLE_DEVICES=all`
   - `NVIDIA_DRIVER_CAPABILITIES=compute,utility`
4. Recheck host driver/CUDA compatibility.

## Migration Problems
Symptoms:
- Missing workspace or old config behavior after migration.

Actions:
1. Re-run migration script with `--dry-run` first.
2. Review backup archive path logged by script.
3. Rollback with `--rollback` if needed.

## Legacy Tailscale Settings Still Present
Symptoms:
- Old config still references in-container Tailscale.

Actions:
1. Remove `TAILSCALE_AUTHKEY` from template.
2. Remove `/var/lib/tailscale` mount.
3. Verify `openclaw.json` no longer contains `gateway.tailscale` fields.
