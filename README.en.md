<p align="right"><b>English</b> · <a href="README.md">Русский</a></p>

<p align="center">
  <img src="ol.png" alt="open-lzt" width="100%">
</p>

<p align="center">
  <strong>Self-hosted lzt.market automation stand — five services, one command, one server.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.12">
  <img src="https://img.shields.io/badge/postgres-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="Postgres 16">
  <img src="https://img.shields.io/badge/redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis 7">
  <img src="https://img.shields.io/badge/systemd-managed-333333?style=for-the-badge&logo=linux&logoColor=white" alt="systemd">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License: MIT"></a>
</p>

**open-lzt** bundles the five lzt projects — the `pylzt` SDK, the `testnet` mock market, the `eventus` event engine, the `flow` automation service, and the `mcp` server for AI agents — into one monorepo that installs on a single Linux host with `./install.sh`. It ships in **testnet mode** by default: every service talks to the in-stand mock, so nothing touches the real marketplace until you flip one switch.

> **New here?** Start with [**Why open-lzt exists**](docs/WHY.en.md) — plain-language, ground up. Then
> the [**architecture map**](docs/ARCHITECTURE.en.md) for how every repo connects, and
> [**CONTRIBUTING**](CONTRIBUTING.en.md) to build a flow, a plugin, or send a PR.

### The projects

| Project | Role | Docs |
|---|---|---|
| [pylzt](https://github.com/open-lzt/pylzt) | Typed async SDK over the market API — the foundation | [README](https://github.com/open-lzt/pylzt#readme) |
| [testnet](https://github.com/open-lzt/lzt-testnet) | Mock lzt.market — the offline double every service hits | [docs/for_ai](https://github.com/open-lzt/lzt-testnet/tree/main/docs/for_ai) |
| [eventus](https://github.com/open-lzt/lzt-eventus) | Event engine: poll → durable log → REST/webhook/SSE/WS | [architecture](https://github.com/open-lzt/lzt-eventus/blob/main/docs/architecture.md) · [extending](https://github.com/open-lzt/lzt-eventus/blob/main/docs/extending.md) |
| [eventus-sdk](https://github.com/open-lzt/lzt-eventus-sdk) | Async client for eventus | [architecture](https://github.com/open-lzt/lzt-eventus-sdk/blob/main/docs/architecture.md) |
| [flow](https://github.com/open-lzt/auto-lzt) | No-code automation engine (flows + plugins) | [flow-design](https://github.com/open-lzt/auto-lzt/blob/main/docs/flow-design-guide.md) · [modules](https://github.com/open-lzt/auto-lzt/blob/main/docs/modules.md) · [plugins](https://github.com/open-lzt/auto-lzt/blob/main/docs/plugins.md) |
| [mcp](https://github.com/open-lzt/lzt-mcp) | MCP server for AI agents (testnet-default) | [README](https://github.com/open-lzt/lzt-mcp#readme) |
| [lzt-ui](https://github.com/open-lzt/lzt-ui) | LZT-style UI kit: tokens, components, demo forum | [README](https://github.com/open-lzt/lzt-ui#readme) |

[AI-agent docs](docs/for_ai/) · [Architecture](docs/ARCHITECTURE.en.md) · [Why](docs/WHY.en.md) · [Contributing](CONTRIBUTING.en.md) · [Marketplace API traps](docs/lzt-gotchas/)

---

## Quickstart — install everything on a fresh server

Target: Ubuntu 22.04 / 24.04, root. Docker, `uv`, and every dependency are installed by the script; you need nothing preinstalled.

**1. Get the code onto the server** (`/opt/open-lzt`) — pick one:

Everything installs with **one command** — it clones the submodules, installs Docker + `uv`, brings up Postgres and Redis, creates both databases, generates every secret (including the Postgres password), renders per-service env files, syncs every project, applies both Alembic migration chains, installs and starts the five `systemd` services, and runs a health check:

```bash
git clone https://github.com/open-lzt/open-lzt.git /opt/open-lzt \
  && cd /opt/open-lzt && sudo bash quickstart.sh
```

`quickstart.sh` fetches the submodules and runs the installer. Re-running it at any time is safe
(idempotent) and doubles as the reconfigure path.

**2. Verify** — all five services should report healthy:

```bash
cd /opt/open-lzt && set -a && . .env && set +a && bash scripts/healthcheck.sh
```

```
  ok testnet        http://127.0.0.1:8765/testnet/health
  ok eventus        http://127.0.0.1:27543/healthz
  ok flow           http://127.0.0.1:8000/catalog/list
  ok mcp            :8770 (listening)
```

> All ports bind to `127.0.0.1` — this is an internal stand. Reach the services from your workstation over an SSH tunnel (see [Remote access](#remote-access)), not by exposing them publicly.

---

## Install a ready-made flow — one command

The stand is up; now you want an actual scenario. `install-flow.sh` takes a module from the
catalogue, asks for its parameters and creates the flow:

```bash
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/install-flow.sh | sudo bash
```

It prints a numbered menu of modules, asks for price, count and dry-run, creates the flow and
offers to start it.

**It does not install the stand.** With no stand present it prints the `install.sh` command and
exits — it downloads nothing and installs nothing on its own.

Unattended, from a script or CI, the same thing with flags:

```bash
sudo bash install-flow.sh --module steam-autobuy --param max_price=10 --param count=1 --run
```

Anything passed with `--param` is never asked for. With no terminal at all the remaining
parameters take their declared defaults — the script never blocks.

The modules live in [lzt-flows](lzt-flows/), which also lists what already ships.

---

## What runs where

| Service | systemd unit | Port (127.0.0.1) | Role |
|---|---|---|---|
| testnet | `open-lzt-testnet` | `8765` | Mock lzt.market API — the test double every service hits in testnet mode |
| eventus | `open-lzt-eventus` | `27543` | Event engine: polls the market, emits domain events over REST/webhook/SSE/WS |
| flow API | `open-lzt-flow-api` | `8000` | Flow-automation HTTP API |
| flow worker | `open-lzt-flow-worker` | — | arq queue + scheduler + embedded event router |
| mcp | `open-lzt-mcp` | `8770` | MCP server — lets an AI agent drive/test the market safely on the testnet |
| Postgres | docker `open-lzt-postgres-1` | `55432` | Two databases: `lztflow`, `lzteventus` |
| Redis | docker `open-lzt-redis-1` | `56379` | Queues, dedup, caching |

Infra (Postgres, Redis) runs in Docker; the five Python services run under `systemd` via `uv`.

---

## Operations

### Monitor

```bash
# One-shot health of every service
cd /opt/open-lzt && set -a && . .env && set +a && bash scripts/healthcheck.sh

# Cross-service smoke test (testnet -> eventus -> flow, no real market hit)
bash scripts/smoke.sh

# Live status / logs of a single service
systemctl status open-lzt-eventus
journalctl -u open-lzt-flow-worker -f

# Infra containers
docker compose ps
docker compose logs -f postgres
```

### Update

```bash
cd /opt/open-lzt && sudo bash update.sh
```

Pulls the monorepo, advances every project **submodule to the latest commit of its tracked branch**
(so new project code actually lands), re-syncs dependencies, applies new migrations, restarts every
service, and re-runs the health check — health-gated: a failing service leaves the previous units
running for inspection.

### Auto-update (optional, off by default)

The stand can track each project's git branch and roll forward automatically, gated on an e2e test
and a health check with rollback. It ships **disabled** — see [docs/AUTOUPDATE.md](docs/AUTOUPDATE.md)
to enable it per service. Dry-run at any time:

```bash
sudo bash deploy/autoupdate.sh --dry-run
```

### Control individual services

```bash
# Restart / stop / start one service
sudo systemctl restart open-lzt-flow-api
sudo systemctl stop     open-lzt-mcp
sudo systemctl start    open-lzt-mcp

# Restart the whole stand
for s in testnet eventus flow-api flow-worker mcp; do sudo systemctl restart open-lzt-$s; done
```

### Switch market mode (testnet <-> prod)

```bash
cd /opt/open-lzt
# testnet (default): all services hit the in-stand mock, zero real-market risk
sed -i 's/^MARKET_MODE=.*/MARKET_MODE=testnet/' .env
# prod: real lzt.market — requires real tokens in EVENTUS_TOKENS
sed -i 's/^MARKET_MODE=.*/MARKET_MODE=prod/' .env
sed -i 's/^EVENTUS_TOKENS=.*/EVENTUS_TOKENS=["your-real-token"]/' .env
sudo ./install.sh   # re-renders env files + restarts; idempotent
```

### Uninstall

```bash
cd /opt/open-lzt
# stop + disable services
for s in testnet eventus flow-api flow-worker mcp; do
  sudo systemctl disable --now open-lzt-$s
  sudo rm -f /etc/systemd/system/open-lzt-$s.service
done
sudo systemctl daemon-reload
# stop infra. Add -v to ALSO delete the Postgres/Redis data volumes (irreversible).
docker compose down          # keeps data
# docker compose down -v     # wipes lztflow + lzteventus databases too
```

The repo checkout and `deploy/env/*.env` stay on disk until you `rm -rf /opt/open-lzt`.

---

## Integration surfaces

Distinct ways to work with a running stand. Reach loopback ports via an [SSH tunnel](#remote-access) first.

### AI agent over MCP (test the market safely)

Point your MCP client at the server (`http://127.0.0.1:8770` through the tunnel), or drive the tool directly. In testnet mode `send_request` hits the mock — no real money, no real token:

```python
from lzt_dev_mcp.testing.tools import send_request

# market-scoped method
lot = await send_request(method_name="GetLot", params={"item_id": 123}, target="testnet")
# forum-scoped method — also stays on the testnet (no prod leak)
cats = await send_request(method_name="CategoriesGet", params={"category_id": 1}, target="testnet")
assert lot.status == 200 and cats.status == 200
```

### REST — flow automation API

```bash
curl -s http://127.0.0.1:8000/catalog/list \
     -H "X-API-Key: $(grep ^FLOW_API_KEY= /opt/open-lzt/.env | cut -d= -f2)"
```

### REST — eventus event engine

```bash
# readiness + a subscription poll (admin key from .env -> deploy/env/eventus.env)
curl -s http://127.0.0.1:27543/healthz
curl -s http://127.0.0.1:27543/subscriptions \
     -H "Authorization: Bearer $(grep ^EVENTUS_ADMIN_API_KEY= /opt/open-lzt/.env | cut -d= -f2)"
```

### Drive the testnet directly

```bash
curl -s http://127.0.0.1:8765/testnet/health
curl -s -X POST http://127.0.0.1:8765/testnet/reset          # clear in-memory state
curl -s -X POST http://127.0.0.1:8765/testnet/revoke-token \
     -H 'Content-Type: application/json' -d '{"token":"testnet-fake-token"}'
```

---

## Public access (HTTPS)

By default the stand is loopback-only (reach it via the SSH tunnel below). During `install.sh` it
asks whether to expose it over HTTPS:

- **Enter a domain** → it installs nginx + a **Let's Encrypt** cert (`certbot`, auto-renewing) and
  reverse-proxies `https://<domain>/` → flow API, `https://<domain>/eventus/` → eventus. The domain's
  DNS must already point at the server and ports 80/443 must be open.
- **No domain** → it offers a **self-signed cert on the server's IP** (browsers show a warning).
- **Neither** → stays loopback-only.

Re-run `sudo bash install.sh` (or set `DOMAIN` / `TLS_MODE` in `.env`) to change this later; the TLS
setup lives in `deploy/setup_tls.sh`.

## Remote access

Without a public domain, services listen on `127.0.0.1` only. Tunnel the ports you need from your
workstation:

```bash
ssh -N \
  -L 8000:127.0.0.1:8000 \
  -L 8770:127.0.0.1:8770 \
  -L 27543:127.0.0.1:27543 \
  -L 8765:127.0.0.1:8765 \
  root@SERVER_IP
# now http://localhost:8000, :8770, :27543, :8765 reach the stand
```

---

## Development & tests

Each project is a standalone `uv` package. Run its suite from the project directory:

```bash
cd projects/mcp     && uv run pytest -q       # MCP server + live-testnet regression
cd projects/testnet && uv run pytest -q       # mock server (roundtrips all methods)
cd projects/flow    && uv run pytest -q -m "not live and not e2e and not pg"
cd projects/eventus && uv run pytest -q -m "not live and not e2e"
```

---

## Contributing

Run the relevant project's suite (above) and keep `ruff`, `ruff format`, and `mypy` clean before a PR:

```bash
cd projects/<name>
uv run ruff check . && uv run ruff format --check . && uv run mypy src   # or `app` for flow
```

Use the issue tracker for bugs and feature requests.

## Authors

<a href="https://github.com/zlexdev"><img src="https://github.com/zlexdev.png" width="48" height="48" style="border-radius:50%" alt="zlexdev" /></a>

## License

[MIT](LICENSE) © 2026 zlexdev
