# Troubleshooting

## Permission Denied on Startup
Symptoms:
- Startup fails with directory creation/write errors under `/home/node/.openclaw`.
- Logs show `EACCES: permission denied, open '/home/node/.openclaw/openclaw.json'`.

Actions:
1. Confirm host path ownership/permissions on appdata and workspace.
2. For one-time repair, start container as root and set:
   - `PUID=<target uid>`
   - `PGID=<target gid>`
   - `OPENCLAW_CHOWN=auto` (or `true` if you want forced recursive repair)
3. Restart container. The entrypoint now repairs file-level ownership drift (including `openclaw.json`) when needed.
4. Run `openclaw onboard` (not `node dist/index.js onboard`) so CLI writes stay under the runtime `node` user.

## Gateway Token Required Error
Symptoms:
- Entry fails with `OPENCLAW_GATEWAY_TOKEN is required`.

Actions:
1. Set `OPENCLAW_GATEWAY_TOKEN` in template.
2. Use a high-entropy token (`openssl rand -hex 24`).

## UI Not Reachable
Symptoms:
- Browser cannot open `http://UNRAID-IP:18800` (or your mapped host port).

Actions:
1. Confirm container is running.
2. Confirm port mapping for `18789/tcp` in bridge mode.
3. Check host firewall/network rules.
4. If using Tailscale, verify host-level reachability to Unraid node.

## Control UI Origin Policy Error (OpenClaw `v2026.2.23+`)
Symptoms:
- Logs show `Gateway failed to start: Error: non-loopback Control UI requires gateway.controlUi.allowedOrigins ...`

Actions:
1. Pull the latest image and restart the container (the entrypoint now auto-patches `openclaw.json` for one-shot Unraid startup).
2. Confirm `/home/node/.openclaw` (host appdata mount) is writable by the runtime user:
   - keep `OPENCLAW_CHOWN=auto` (recommended), or
   - run once as root with `PUID`/`PGID` for permission alignment.
3. Verify advanced template vars:
   - `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` (defaults to `http://[IP]:[PORT:18800]`)
   - `OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK=auto`
4. For hardened setups, explicitly set all expected origins (IP, hostname, reverse proxy/Tailscale URL) and set fallback to `false`.

## Pairing Required / WebSocket 1008
Symptoms:
- Control UI shows `disconnected (1008): pairing required`.
- Logs include `reason=pairing required` or `token_missing`.

Actions:
1. Open the UI URL with your gateway token:
   - `https://<tailscale-hostname>.<tailnet>.ts.net/?token=<OPENCLAW_GATEWAY_TOKEN>`
2. Complete device pairing once, then reconnect.
3. If this appears together with `EACCES` on `openclaw.json`, fix permissions first, then retry pairing.

## Trusted Proxy Warning With Native Tailscale
Symptoms:
- Logs show `Proxy headers detected from untrusted address... configure gateway.trustedProxies`.

Actions:
1. This warning is expected when access is proxied and no trusted proxy list is set.
2. Set `OPENCLAW_TRUSTED_PROXIES=127.0.0.1,::1` in the template (advanced section).
3. Restart the container so entrypoint writes `gateway.trustedProxies` into `/home/node/.openclaw/openclaw.json`.

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

## Power Profile: Homebrew or Playwright Issues
Symptoms:
- `brew: command not found` in the power image.
- Browser tool actions fail and logs mention missing Playwright/Chromium browser binaries.

Actions:
1. Confirm you are running the `power` image/template (`openclaw-unraid-cuda:power-*` tags).
2. Verify Homebrew:
   - `command -v brew`
   - `brew --version`
3. Verify Playwright cache path:
   - `echo \"$PLAYWRIGHT_BROWSERS_PATH\"` (should be `/home/node/.cache/ms-playwright`)
   - `find /home/node/.cache/ms-playwright -maxdepth 5 -type f | grep -E 'chrome|chromium'`
4. If using a mount for `/home/node/.cache/ms-playwright`, confirm it is writable by the container runtime user.
5. If Playwright endpoints still report unavailable support, confirm the current OpenClaw build includes the expected browser dependencies and review power-profile release notes for known limitations.

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
