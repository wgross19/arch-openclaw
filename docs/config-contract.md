# Configuration Contract (v1)

## Runtime Command Contract
Default container startup resolves to:

```bash
node dist/index.js gateway --bind ${OPENCLAW_GATEWAY_BIND:-lan} --port ${OPENCLAW_GATEWAY_PORT:-18789} --allow-unconfigured
```

## Required Environment Variables
| Variable | Required | Default | Notes |
|---|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | Yes | none | Required for gateway/UI authentication. |

## Core Environment Variables
| Variable | Required | Default | Notes |
|---|---|---|---|
| `OPENCLAW_GATEWAY_PORT` | No | `18789` | Internal port gateway listens on. |
| `OPENCLAW_GATEWAY_BIND` | No | `lan` | Gateway bind mode. Accepted values include `lan`, `loopback`, `tailnet`, `auto`, and `custom`. |
| `TZ` | No | unset | Optional timezone override (template sets a concrete default). |
| `NVIDIA_VISIBLE_DEVICES` | No | `all` | GPU visibility selection when GPU is enabled. |
| `NVIDIA_DRIVER_CAPABILITIES` | No | `compute,utility` | NVIDIA driver capabilities exposed to the container. |

## Provider API Keys (Optional)
- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `OPENROUTER_API_KEY`
- `GEMINI_API_KEY`
- `GROQ_API_KEY`
- `XAI_API_KEY`
- `ZAI_API_KEY`

All provider keys default to empty and are never hardcoded in template values.

## Optional Permission Variables
| Variable | Required | Default | Notes |
|---|---|---|---|
| `PUID` | No | unset | Optional UID remap when container starts as root for ownership repair. |
| `PGID` | No | unset | Optional GID remap when container starts as root for ownership repair. |
| `OPENCLAW_CHOWN` | No | `auto` | `auto` repairs ownership only when write checks fail, `true` always repairs, `false` disables repair. |
| `OPENCLAW_TRUSTED_PROXIES` | No | `127.0.0.1,::1` (template default) | Comma-separated list or JSON array written to `gateway.trustedProxies` in `openclaw.json` at startup. |

## Volume Contract

### Required Mounts
| Host Path | Container Path | Mode | Purpose |
|---|---|---|---|
| `/mnt/user/appdata/openclaw` | `/home/node/.openclaw` | `rw` | Config, auth, agent state |
| `/mnt/user/appdata/openclaw/workspace` | `/home/node/.openclaw/workspace` | `rw` | Workspace files and memory |

### Optional Mounts (Advanced)
| Host Path (example) | Container Path | Mode | Purpose |
|---|---|---|---|
| `/mnt/user/appdata/openclaw/projects` | `/projects` | `rw` | External code/project workspace |
| `/mnt/user/appdata/openclaw/qmd-cache` | `/home/node/.cache/qmd` | `rw` | QMD/model cache persistence |
| `/mnt/user/appdata/openclaw/bun` | `/home/node/.bun` | `rw` | Bun persistence for advanced workflows |
| `/mnt/user/appdata/openclaw/homebrew` | `/home/linuxbrew/.linuxbrew` | `rw` | Homebrew persistence for advanced workflows |

## Network Contract
- Default mode: `bridge`.
- Required mapped port: `18789/tcp`.
- Optional mapped port: `18790/tcp` only when bridge features are enabled.
- Remote access over Tailscale is handled by the Unraid host, not this container.
- When using Unraid native container Tailscale integration, the hook runs as root and then starts the original entrypoint.

## Removed Legacy Surface (Breaking)
- `TAILSCALE_AUTHKEY` environment variable.
- `/var/lib/tailscale` mount.
- In-container `tailscaled` startup workflow.
- Runtime package install/bootstrap scripts.
- `--cap-add=NET_ADMIN` and legacy `--runtime=nvidia` defaults.

## Upgrade Notes
When migrating from legacy templates:
- Move to `/home/node/.openclaw` container path contract.
- Remove legacy Tailscale env/mount entries.
- Ensure `OPENCLAW_GATEWAY_TOKEN` is explicitly set in the template.
- Use migration tooling in `scripts/migrate-legacy-openclaw.sh` before switching templates.
