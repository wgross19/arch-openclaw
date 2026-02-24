# OpenClaw Unraid CUDA Distribution

Dedicated repository for a hardened, CA-ready Unraid distribution of OpenClaw with pinned NVIDIA CUDA runtime libraries.

## What This Repo Contains
- `Dockerfile.unraid-cuda`: production image build definition.
- `docker/entrypoint.sh`: startup and permission handling.
- `docker/healthcheck.sh`: gateway liveness check.
- `templates/openclaw-unraid-cuda.xml`: Unraid Community Apps template.
- `templates/openclaw-unraid-cuda-power.xml`: optional Unraid template for the power profile image.
- `scripts/migrate-legacy-openclaw.sh`: migration and rollback helper.
- `scripts/unraid-debug-cycle.sh`: one-shot Unraid debug capture + onboarding runner.
- `docs/`: architecture, install, migration, testing, release, and tracking docs.
- `.github/workflows/build-test-release.yml`: CI build/test/scan/publish pipeline.

## Build Locally
Set an upstream tag in `/Users/wfg/Projects/arch-openclaw/.openclaw-ref` (currently pinned to `v2026.2.23`) or pass `OPENCLAW_REF` directly.

```bash
docker build \
  -f Dockerfile.unraid-cuda \
  --target runtime-core \
  --build-arg OPENCLAW_REF=<upstream-tag> \
  -t openclaw-unraid-cuda:core-local .
```

Build the optional power profile (Homebrew + Playwright/Chromium + extra tooling):

```bash
docker build \
  -f Dockerfile.unraid-cuda \
  --target runtime-power \
  --build-arg OPENCLAW_REF=<upstream-tag> \
  -t openclaw-unraid-cuda:power-local .
```

## Run Locally
```bash
docker run --rm -it \
  -p 18789:18789 \
  -e OPENCLAW_GATEWAY_TOKEN=changeme \
  -v /tmp/openclaw-config:/home/node/.openclaw \
  -v /tmp/openclaw-workspace:/home/node/.openclaw/workspace \
  openclaw-unraid-cuda:core-local
```

## Profiles
- `core` (default): CUDA + OpenClaw + QMD + Bun + ffmpeg + common CLI tooling (`git`, `jq`, `rg`, `tmux`, `python3`, `uv`, `gh`).
- `power` (optional): everything in `core` plus Linuxbrew/Homebrew and Playwright/Chromium browser support.
- Both profiles share the same config/workspace mount contract so operators can switch profiles without data migration.
- For OpenClaw `v2026.2.23+`, the entrypoint auto-patches `openclaw.json` with Control UI origin policy settings on startup (including one-shot Host-header fallback in `auto` mode) so Unraid `lan`-bind installs start without manual config edits.

## Documentation
- Architecture: `docs/architecture.md`
- Config contract: `docs/config-contract.md`
- Install guide: `docs/install-unraid.md`
- Migration guide: `docs/migration-v1.md`
- Test plan: `docs/test-plan.md`
- Release process: `docs/release-process.md`
- Tracking model: `docs/project-tracking.md`
- Session handoff SOP: `docs/session-handoff.md`
