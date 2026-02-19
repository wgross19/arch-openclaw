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
1. In Unraid, open Docker templates and add template URL:
   - `https://raw.githubusercontent.com/wgross19/arch-openclaw/main/templates/openclaw-unraid-cuda.xml`
2. Create container from template.
3. Set required values:
   - `OPENCLAW_GATEWAY_TOKEN`
   - At least one API key (for example `ANTHROPIC_API_KEY`).
4. Confirm required paths:
   - `/mnt/user/appdata/openclaw-cuda` -> `/home/node/.openclaw`
   - `/mnt/user/appdata/openclaw-cuda/workspace` -> `/home/node/.openclaw/workspace`
5. Keep default network mode `bridge` and mapped UI port `18800 -> 18789`.
6. Start the container.

## First-Run Verification
1. Check container logs for successful gateway start.
2. Open UI:
   - Native Tailscale integration enabled: `https://<container-hostname>.<tailnet>.ts.net/?token=YOUR_GATEWAY_TOKEN`
   - No Tailscale integration: use localhost tunneling from your client instead of plain LAN HTTP.
3. Verify persistence:
   - Create a file under workspace and confirm it survives container restart.
4. Verify model provider:
   - Run a simple model request in UI.

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

## Security Checklist
- Keep `OPENCLAW_GATEWAY_TOKEN` secret.
- Do not hardcode provider keys into template defaults.
- Keep `OPENCLAW_CHOWN=auto` unless you need forced recursive ownership repair.
- Do not add `NET_ADMIN` or privileged mode.
