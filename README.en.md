<p align="right"><b>English</b> · <a href="README.md">Русский</a></p>

# open-lzt

A self-hosted [lzt.market](https://lzt.market) automation stand: six services, one command, one Linux host. **Testnet by default — requests go to the built-in mock market, and no real money is spent until you flip the mode yourself.**

Look at it without installing anything:

```bash
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/demo.sh | sudo bash
```

The demo brings the stand up and walks every project through it, showing each request and each response.

| demo.sh flag | What it does |
|---|---|
| `--mode testnet\|prod` | against the mock or the live market |
| `--skip-install` | don't install, use an existing stand |
| `--speed fast\|normal\|slow` | how fast the scenes play |
| `--max-price` · `--count` | parameters of the demo purchase |
| `--no-update` · `--yes` | don't self-update, don't ask |

## Install

Debian or Ubuntu 22.04/24.04, systemd, root. Kubernetes and cloud topologies are not supported — this is one host.

```bash
git clone https://github.com/open-lzt/open-lzt.git /opt/open-lzt \
  && cd /opt/open-lzt && sudo bash quickstart.sh
```

`quickstart.sh` pulls the submodules and calls `install.sh`. If the submodules are already there, install directly:

```bash
sudo ./install.sh --dry-run    # show the plan, change nothing
sudo ./install.sh
```

`install.sh` is idempotent: it installs Docker and uv, brings up Postgres and Redis, syncs every project's dependencies, applies migrations and enables the systemd units.

| install.sh flag | What it does |
|---|---|
| `--market-mode testnet\|prod` | what the stand runs against |
| `--bot-token` · `--bot-admins` | Telegram control bot |
| `--domain` · `--email` · `--tls` | public domain and a Let's Encrypt certificate |
| `--dry-run` · `--yes` | plan only; no questions |

## What comes up

| Service | systemd unit | Port | Role |
|---|---|---|---|
| testnet | `open-lzt-testnet` | 8765 | mock market API |
| eventus | `open-lzt-eventus` | 27543 | event engine and management API |
| flow API | `open-lzt-flow-api` | 8000 | automation HTTP API |
| flow worker | `open-lzt-flow-worker` | — | arq queue and scheduler |
| mcp | `open-lzt-mcp` | 8770 | MCP server for AI agents |
| bot | `open-lzt-bot` | — | Telegram bot, only when enabled |
| Postgres | container | 55432 | the `lztflow` and `lzteventus` databases |
| Redis | container | 56379 | queues, dedup, cache |

Every port listens on `127.0.0.1`. The stand is reachable from outside only through nginx, and only if you set a domain.

Scheduled self-update lives in the `open-lzt-autoupdate.service` and `.timer` units — see [docs/AUTOUPDATE.en.md](docs/AUTOUPDATE.en.md).

## testnet or prod

The mode is `MARKET_MODE` in `.env`, or the `--market-mode` flag at install time. In `testnet` no market token is needed at all. Switching to `prod` is the one moment the stand starts spending real money.

## What's inside

Eight submodules.

| Path | Repository | What it is |
|---|---|---|
| `projects/pylzt` | [pylzt](https://github.com/open-lzt/pylzt) | typed async SDK over the market, forum and AntiPublic APIs. The foundation |
| `projects/testnet` | [lzt-testnet](https://github.com/open-lzt/lzt-testnet) | mock market server, the offline double used in tests |
| `projects/eventus` | [lzt-eventus](https://github.com/open-lzt/lzt-eventus) | event engine: poll → log → webhook, SSE, WS, REST |
| `projects/eventus-sdk` | [lzt-eventus-sdk](https://github.com/open-lzt/lzt-eventus-sdk) | client for the event engine |
| `projects/flow` | [auto-lzt](https://github.com/open-lzt/auto-lzt) | no-code automation, a task as a graph |
| `projects/mcp` | [lzt-mcp](https://github.com/open-lzt/lzt-mcp) | MCP server that lets an AI agent work with the market |
| `projects/lzt-ui` | [lzt-ui](https://github.com/open-lzt/lzt-ui) | UI kit for the web panel |
| `lzt-flows` | [lzt-flows](https://github.com/open-lzt/lzt-flows) | catalog of ready-made flow modules |

## Updating and ready-made flows

```bash
sudo ./update.sh                                                              # rolling update
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/install-flow.sh | sudo bash   # install a ready flow
```

## Configuration

`.env` is created by the installer, which also generates the secrets. The essentials:

| Variable | Default | What it is |
|---|---|---|
| `MARKET_MODE` | `testnet` | what the stand runs against |
| `TESTNET_PORT` · `EVENTUS_PORT` · `FLOW_PORT` · `MCP_PORT` | 8765 · 27543 · 8000 · 8770 | service ports |
| `POSTGRES_PORT` · `REDIS_PORT` | 55432 · 56379 | container ports |
| `FLOW_MASTER_KEY` · `EVENTUS_TOKEN_ENC_KEY` | generated | token encryption; two distinct keys, not interchangeable |
| `FLOW_API_KEY` · `EVENTUS_ADMIN_API_KEY` | generated | API access |
| `EVENTUS_TOKENS` | `[]` | market tokens, a JSON array in single quotes |
| `LZT_FLOW_EGRESS_ALLOWED_HOSTS` | `api.telegram.org` | where request nodes may go |
| `BOT_ENABLED` · `BOT_TOKEN` · `BOT_ADMIN_IDS` | `0` | Telegram bot |
| `DOMAIN` · `TLS_MODE` · `LETSENCRYPT_EMAIL` | empty · `none` | public access and certificate |

The full annotated list is in `.env.example`.

## Operating it

```bash
scripts/healthcheck.sh                  # every service at once
scripts/smoke.sh                        # end-to-end check of the stand
journalctl -u open-lzt-flow-api -f      # service logs
systemctl stop open-lzt-flow-api        # stop a service
```

## Documentation

[Why this exists](docs/WHY.en.md) — from the ground up, in plain language · [Architecture](docs/ARCHITECTURE.en.md) — every repo and every link · [Auto-update](docs/AUTOUPDATE.en.md) · [Panel architecture](docs/panel-architecture.md) (Russian) · [Market API gotchas](docs/lzt-gotchas/) (Russian) · [AI-agent docs](docs/for_ai/index.en.md) · [Contributing](CONTRIBUTING.en.md)

## License

[MIT](LICENSE)
