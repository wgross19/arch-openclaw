# OpenClaw Unraid CUDA Distribution

Dedicated repository for a hardened, CA-ready Unraid distribution of OpenClaw with pinned NVIDIA CUDA runtime libraries.

## What This Repo Contains
- `Dockerfile.unraid-cuda`: production image build definition.
- `docker/entrypoint.sh`: startup and permission handling.
- `docker/healthcheck.sh`: gateway liveness check.
- `templates/openclaw-unraid-cuda.xml`: Unraid Community Apps template.
- `scripts/migrate-legacy-openclaw.sh`: migration and rollback helper.
- `scripts/unraid-debug-cycle.sh`: one-shot Unraid debug capture + onboarding runner.
- `docs/`: architecture, install, migration, testing, release, and tracking docs.
- `.github/workflows/build-test-release.yml`: CI build/test/scan/publish pipeline.

## Build Locally
Set an upstream tag in `/Users/wfg/Projects/arch-openclaw/.openclaw-ref` (replace `SET_ME_TO_OPENCLAW_TAG`) or pass `OPENCLAW_REF` directly.

```bash
docker build \
  -f Dockerfile.unraid-cuda \
  --build-arg OPENCLAW_REF=<upstream-tag> \
  -t openclaw-unraid-cuda:local .
```

## Run Locally
```bash
docker run --rm -it \
  -p 18789:18789 \
  -e OPENCLAW_GATEWAY_TOKEN=changeme \
  -v /tmp/openclaw-config:/home/node/.openclaw \
  -v /tmp/openclaw-workspace:/home/node/.openclaw/workspace \
  openclaw-unraid-cuda:local
```

## Documentation
- Architecture: `docs/architecture.md`
- Config contract: `docs/config-contract.md`
- Install guide: `docs/install-unraid.md`
- Migration guide: `docs/migration-v1.md`
- Test plan: `docs/test-plan.md`
- Release process: `docs/release-process.md`
- Tracking model: `docs/project-tracking.md`
- Session handoff SOP: `docs/session-handoff.md`
