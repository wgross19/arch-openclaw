# Migration Guide: Legacy Unraid Template -> v1 Hardened Template

## Scope
Use this guide when migrating from legacy templates that:
- Mounted data to `/root/.openclaw` in-container.
- Started OpenClaw with runtime bootstrap commands.
- Included in-container Tailscale startup state.

v1 contract moves runtime to `/home/node/.openclaw` and removes in-container Tailscale behavior.

## Preflight
1. Stop the legacy OpenClaw container.
2. Confirm appdata source path exists (default `/mnt/user/appdata/openclaw`).
3. Ensure backup destination has enough free space.
4. Export current template values or screenshot current env/path settings.

## Backup
Create a backup before migration:

```bash
bash scripts/migrate-legacy-openclaw.sh \
  --legacy-root /mnt/user/appdata/openclaw \
  --target-root /mnt/user/appdata/openclaw \
  --backup-dir /mnt/user/appdata/openclaw-migration-backups \
  --dry-run
```

Then run without `--dry-run`.

## Transform
Recommended command:

```bash
bash scripts/migrate-legacy-openclaw.sh \
  --legacy-root /mnt/user/appdata/openclaw \
  --target-root /mnt/user/appdata/openclaw \
  --backup-dir /mnt/user/appdata/openclaw-migration-backups
```

What it does:
- Creates a timestamped backup archive.
- Validates workspace and config structure.
- Removes legacy Tailscale-specific config keys from `openclaw.json` when possible.
- Ensures required target directories exist.

## Environment Mapping
Retained variables:
- `OPENCLAW_GATEWAY_TOKEN`
- Provider API keys (`ANTHROPIC_API_KEY`, etc.)
- `OPENCLAW_GATEWAY_PORT`
- `NVIDIA_VISIBLE_DEVICES`, `NVIDIA_DRIVER_CAPABILITIES`

Deprecated variables:
- `TAILSCALE_AUTHKEY`

Optional env mapping output:

```bash
bash scripts/migrate-legacy-openclaw.sh \
  --legacy-root /mnt/user/appdata/openclaw \
  --target-root /mnt/user/appdata/openclaw \
  --env-file /path/to/legacy.env \
  --output-env-file /path/to/new.env
```

## Validation
After migration and template switch:
1. Start container with new v1 template.
2. Confirm UI is reachable at `http://UNRAID-IP:18789/?token=...`.
3. Confirm workspace files are present.
4. Confirm logs do not show in-container Tailscale startup attempts.

## Rollback
If migration fails, restore from archive:

```bash
bash scripts/migrate-legacy-openclaw.sh \
  --target-root /mnt/user/appdata/openclaw \
  --rollback /mnt/user/appdata/openclaw-migration-backups/openclaw-legacy-YYYYMMDD-HHMMSS.tgz
```

The script preserves the failed target as `*.pre-rollback-<timestamp>` before restoring.

## Common Issues
- Permission denied on startup:
  - Ensure appdata owner/group is compatible with runtime UID/GID.
  - Temporarily run with root + `PUID/PGID` and `OPENCLAW_CHOWN=true` one time.
- Missing token error:
  - Set `OPENCLAW_GATEWAY_TOKEN` in template variables.
- GPU unavailable:
  - Verify Unraid NVIDIA plugin and host driver/toolkit version.
