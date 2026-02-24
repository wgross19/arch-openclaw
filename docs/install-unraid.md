# Install OpenClaw Unraid CUDA

## Prerequisites
1. Unraid 6.12+.
2. NVIDIA Driver plugin installed on Unraid (for GPU use).
3. Host-level Tailscale configured if remote tailnet access is desired.
4. A generated gateway token and at least one provider API key.

Example token generation:

```bash
openssl rand -hex 24
```

## Install via Template URL (Beta Channel)
Choose one template:
1. `core` (recommended default): `https://raw.githubusercontent.com/wgross19/arch-openclaw/main/templates/openclaw-unraid-cuda.xml`
2. `power` (advanced tooling): `https://raw.githubusercontent.com/wgross19/arch-openclaw/main/templates/openclaw-unraid-cuda-power.xml`

1. In Unraid, open Docker templates and add template URL:
   - Use the `core` or `power` template URL above.
2. Create container from template.
3. Set required values:
   - `OPENCLAW_GATEWAY_TOKEN`
   - At least one API key (for example `ANTHROPIC_API_KEY`).
4. Confirm required paths:
   - `/mnt/user/appdata/openclaw-cuda` -> `/home/node/.openclaw`
   - `/mnt/user/appdata/openclaw-cuda/workspace` -> `/home/node/.openclaw/workspace`
5. Keep default network mode `bridge` and mapped UI port `18800 -> 18789`.
6. Start the container.
7. Leave the advanced Control UI origin settings at defaults unless you have a specific hardening requirement:
   - `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` defaults to `http://[IP]:[PORT:18800]`
   - `OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK` defaults to `auto`

Notes:
- `core` is the default CA-oriented profile and is the recommended starting point.
- `power` adds Homebrew + Playwright/Chromium + additional CLI tooling for better OpenClaw skill compatibility.
- Both templates intentionally use the same config/workspace paths so you can switch profiles without migrating appdata. Do not run both profiles at the same time against the same paths.
- In OpenClaw `v2026.2.23+`, non-loopback bind modes require a Control UI origin policy. This image writes the policy into `/home/node/.openclaw/openclaw.json` automatically on startup so first-run Unraid installs work without manual edits.

## First-Run Verification
1. Check container logs for successful gateway start.
2. (Optional) Open container console and run onboarding:
   - `openclaw onboard`
   - Use the `openclaw` command (not `node dist/index.js`) so writes stay on the runtime user.
3. Open UI:
   - Unraid template WebUI link (default): `http://<UNRAID-IP>:<mapped-port>/` (for example `http://192.168.1.79:18800/`)
   - Native Tailscale integration enabled: `https://<container-hostname>.<tailnet>.ts.net/?token=YOUR_GATEWAY_TOKEN`
   - No Tailscale integration: use localhost tunneling from your client instead of plain LAN HTTP.
4. If prompted for pairing in Control UI, complete the pairing flow once.
5. Verify persistence:
   - Create a file under workspace and confirm it survives container restart.
6. Verify model provider:
   - Run a simple model request in UI.
7. Optional tool checks:
   - `core`: `bun --version`, `ffmpeg -version`, `gh --version`
   - `power`: `brew --version` and confirm `/home/node/.cache/ms-playwright` is writable (if mounted)

## GPU Enablement Verification
1. Ensure template includes `--gpus all`.
2. Confirm `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=compute,utility`.
3. In container shell, verify GPU visibility:

```bash
nvidia-smi
```

If `nvidia-smi` fails, check host NVIDIA plugin and driver compatibility.

## Host Tailscale Access Model
- This container does not run `tailscaled`.
- Access control should be configured on Unraid host networking/Tailscale ACLs.
- For Unraid native container Tailscale integration:
  - Enable Tailscale in the template.
  - Keep image entrypoint untouched in template options.
  - Keep `OPENCLAW_TRUSTED_PROXIES=127.0.0.1,::1` (advanced var) so forwarded proxy headers are treated as trusted.
  - Use the MagicDNS HTTPS URL exposed by Unraid for browser access.

## Upgrade Path
1. Pull new image tag.
2. Apply template updates.
3. Restart container.
4. If upgrading from legacy `/root/.openclaw` contract, run:

```bash
/boot/config/plugins/dockerMan/templates-user/scripts/migrate-legacy-openclaw.sh
```

or use this repo script directly with your appdata paths.

### Upgrade note for `v2026.2.23+` Control UI origin errors
If an existing container fails with:
- `non-loopback Control UI requires gateway.controlUi.allowedOrigins ...`

then:
1. Pull the updated image.
2. Restart the container once.
3. The entrypoint will patch/create `/home/node/.openclaw/openclaw.json` automatically (assuming the appdata mount is writable).

## Security Checklist
- Keep `OPENCLAW_GATEWAY_TOKEN` secret.
- Do not hardcode provider keys into template defaults.
- Keep `OPENCLAW_CHOWN=auto` unless you need forced recursive ownership repair.
- Do not add `NET_ADMIN` or privileged mode.
