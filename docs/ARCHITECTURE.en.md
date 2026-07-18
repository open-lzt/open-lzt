<p align="right"><b>English</b> · <a href="ARCHITECTURE.md">Русский</a></p>

# open-lzt — Architecture

> One document, the whole ecosystem: every repository, how they connect, and how the stand is
> deployed. Written to be read start-to-finish by an AI agent or a new contributor. Each repository
> also ships a `docs/for_ai/` directory with a machine-oriented map of its own internals — this file
> is the layer *above* those, describing the seams **between** repos.

---

## 1. The one-paragraph model

`pylzt` is a typed async SDK that speaks the lzt.market / lolzteam API. `testnet` is a mock server
that speaks the *same* API, so anything built on `pylzt` can run offline. `eventus` polls the market
through `pylzt`, turns changes into a durable, replayable **event log**, and delivers those events
over REST / webhook / SSE / WS; `eventus-sdk` is its client. `flow` is a no-code automation engine:
it executes user-defined **flow graphs** (trigger → fetch → filter → action → notify), using `pylzt`
for the actions. `mcp` exposes all of this to an AI agent as tools. The `open-lzt` monorepo bundles
the five runnable services into one `systemd` stand, defaulting to testnet so nothing touches a real
account until you flip `MARKET_MODE`.

---

## 2. The layer stack

```
                            ┌───────────────────────────────────────────┐
   AI agent / MCP client ──▶│  mcp            (:8770)  drive + test      │
                            └───────────────────────────────────────────┘
                                     │ tools call into ▼
        ┌────────────────────────────┴───────────────┬──────────────────────────┐
        ▼                                             ▼                          ▼
┌───────────────────┐                       ┌───────────────────┐      ┌───────────────────┐
│ flow   (:8000 api │                       │ eventus  (:27543) │◀────▶│ eventus-sdk       │
│        + worker)  │                       │ poll→log→deliver  │      │ (client library)  │
│ no-code automation│                       └─────────┬─────────┘      └───────────────────┘
└─────────┬─────────┘                                 │
          │  both reach the market through            │
          ▼            the SAME SDK ◀─────────────────┘
                 ┌───────────────────────────┐
                 │ pylzt   (SDK, a library)  │  token pool · rate-limit · proxies · retries
                 └─────────────┬─────────────┘
                               │ HTTP, base URL chosen by MARKET_MODE
              ┌────────────────┴─────────────────┐
              ▼ testnet                            ▼ prod
     ┌───────────────────┐               ┌───────────────────┐
     │ testnet  (:8765)  │               │ api.lzt.market    │
     │ mock market       │               │ (the real market) │
     └───────────────────┘               └───────────────────┘
```

**Dependency direction is strictly downward.** `flow`, `eventus`, and `mcp` depend on `pylzt`;
nothing depends on `flow`/`eventus`/`mcp` except `mcp` (which orchestrates the other two) and
`eventus-sdk` (which is a thin client of `eventus`). `pylzt` depends on nothing in this ecosystem.

---

## 3. Repository by repository

### pylzt — `github.com/open-lzt/pylzt`
The foundation. A typed async client generated from the lzt.market OpenAPI spec, plus the lolzteam
forum and AntiPublic APIs. Not a thin wrapper — it owns the **token pool** (round-robins across many
account tokens), **rate-limiting**, **proxy rotation**, pagination, media upload, and typed error
handling. Every other service reaches the market *only* through this SDK, which is why swapping the
base URL (testnet ↔ prod) is a one-line change nothing else has to know about.

- **Depends on:** nothing in-ecosystem.
- **Consumed by:** `eventus`, `flow`, `mcp`, and directly by user scripts.

### testnet — `github.com/open-lzt/lzt-testnet`
A FastAPI server that reproduces the lzt.market API surface — same routes, same response shapes —
backed by in-memory state. It exists so the whole stack can run and be tested with **no real token
and no real market**. Its endpoints (`/testnet/reset`, `/testnet/revoke-token`) let tests drive edge
cases deterministically. In the stand it listens on `:8765`.

- **Depends on:** nothing (it is the thing others depend on in testnet mode).
- **Consumed by:** every service, whenever `MARKET_MODE=testnet`.

### eventus — `github.com/open-lzt/lzt-eventus`
The event engine. It polls the market through `pylzt`, diffs state into **domain events**
(e.g. a new order, a sold item), writes them to a durable, **replayable** log, and delivers them
through a catch-up bus over REST, webhook (HMAC-signed), SSE, and WebSocket. State lives in the
`lzteventus` Postgres database. In the stand it listens on `:27543` (`/healthz`, `/subscriptions`).

- **Depends on:** `pylzt`, Postgres, Redis.
- **Consumed by:** `eventus-sdk`, `mcp`, and (optionally, embedded) `flow`'s worker. Extension points
  are documented in its `docs/extending.md`.

### eventus-sdk — `github.com/open-lzt/lzt-eventus-sdk`
The async client library for `eventus`'s management API: create/list subscriptions, poll the event
stream, verify webhook signatures. It is what an external app imports to *consume* events without
re-implementing the delivery protocol.

- **Depends on:** `eventus` (as a running service, over HTTP).
- **Consumed by:** external consumer apps.

### flow — `github.com/open-lzt/auto-lzt`
The no-code automation engine, and the largest service. A **flow** is a JSON graph of nodes
(`trigger → fetch → filter → action → notify`); the engine compiles it, then the worker executes it,
using `pylzt` for market actions. It runs as **two units**: an HTTP API (`:8000`, flow CRUD, catalog,
runs) and a worker (arq job queue + APScheduler for time triggers + an optionally-embedded eventus
router). State lives in the `lztflow` Postgres database. Configuration uses the `LZT_FLOW_` env
prefix. It is extensible two ways — see §6.

- **Depends on:** `pylzt`, `eventus` (as a library, `lzt-eventus[engine]`), Postgres, Redis.
- **Consumed by:** `mcp`, the Telegram admin bot (optional), and end users via its API.
- **Canonical guides:** `docs/flow-design-guide.md`, `docs/modules.md`, `docs/plugins.md`.

### mcp — `github.com/open-lzt/lzt-mcp`
An MCP (Model Context Protocol) server that gives an AI agent a safe, typed toolbox over the whole
stand: raw API request testing, flow management, eventus introspection. It is **testnet-default and
prod-guarded** — an agent cannot accidentally hit the real market. Listens on `:8770`.

- **Depends on:** `pylzt`, `testnet`, `flow` + `eventus` (as running services), Postgres/Redis via them.
- **Consumed by:** any MCP client (Claude, IDE agents, etc.).

---

## 4. How they connect at runtime

**Market access (all services).** No service builds HTTP requests to the market itself. They
construct a `pylzt` client with a base URL derived from `MARKET_MODE`. In `testnet` mode that URL is
the local `testnet` service; in `prod` mode it is `api.lzt.market`. This is the single seam that
makes the whole stand safe-by-default.

**Events (eventus → consumers).** `eventus` is the only producer of the event log. Consumers never
poll the market for changes themselves — they subscribe to `eventus` (via `eventus-sdk`, a webhook,
or an SSE/WS stream) and receive replayable events. This keeps polling and rate-limit pressure in one
place.

**flow ↔ eventus.** `flow`'s worker can *embed* an eventus event router in-process (so an event can
trigger a flow) — this is gated by `LZT_FLOW_EMBED_EVENTUS`. **In the bundled stand this is disabled
(`=0`)**: eventus runs as its own standalone service (`open-lzt-eventus`), and flow's worker is
arq + scheduler only. When `flow` is run *alone* (outside the stand), it can turn the embedded router
on. Two deployment shapes, one codebase.

**mcp → everything.** `mcp` is the orchestration layer for agents. Its tools call `pylzt` for raw
requests, `flow`'s API for automation management, and `eventus` for event introspection — always
respecting the testnet guard.

---

## 5. Deploy topology (the `open-lzt` stand)

The monorepo is **infra-in-Docker, services-under-systemd**. `docker-compose.yml` runs only Postgres
and Redis (bound to loopback); the five Python services run as `systemd` units via `uv run`.
`install.sh` (idempotent) generates every secret, creates both databases, applies both Alembic
migration chains, and starts the units.

| Unit / container | systemd unit | Port (127.0.0.1) | Backing store |
|---|---|---|---|
| testnet | `open-lzt-testnet` | `8765` | in-memory |
| eventus | `open-lzt-eventus` | `27543` | Postgres `lzteventus` |
| flow API | `open-lzt-flow-api` | `8000` | Postgres `lztflow` |
| flow worker | `open-lzt-flow-worker` | — | Postgres `lztflow` + Redis |
| mcp | `open-lzt-mcp` | `8770` | via flow/eventus |
| Postgres | docker `open-lzt-postgres-1` | `55432` | volumes: `lztflow`, `lzteventus` |
| Redis | docker `open-lzt-redis-1` | `56379` | queues, dedup, cache |

- **Config prefixes:** `flow` reads `LZT_FLOW_*`; `eventus` reads `LZT_*`. The top-level `.env` is the
  single source; `install.sh` renders per-service `deploy/env/*.env` from it.
- **Postgres drivers:** async access uses `asyncpg` (`postgresql+asyncpg://`); the APScheduler
  jobstore, which is sync-only, uses `psycopg` v3 (`postgresql+psycopg://`). **`psycopg2` is never
  used** — a bare `postgresql://` URL is normalized to the right driver in code before an engine is
  built.
- **Market mode:** `MARKET_MODE=testnet|prod` in `.env`; switching to prod additionally requires real
  tokens in `EVENTUS_TOKENS`. Re-run `install.sh` to apply (it re-renders env + restarts).
- **Ports are loopback-only**; reach them via SSH tunnel, or expose flow/eventus over HTTPS through
  the optional nginx + Let's Encrypt setup (`deploy/setup_tls.sh`).

Ops surface: `scripts/healthcheck.sh`, `scripts/smoke.sh`, `update.sh` (health-gated rolling update),
`deploy/autoupdate.sh` (optional, off by default — see `docs/AUTOUPDATE.md`).

---

## 6. The two extension models (important — they are not the same)

`flow` can be extended in two fundamentally different ways. Confusing them is the most common mistake.

| | **FLOW module** (`kind: flow`) | **PYTHON plugin** (`kind: python`) |
|---|---|---|
| **What it is** | A flow graph as **data** (JSON/YAML) | **Executable Python** — new node types, routers, handlers |
| **Who can publish** | Anyone | **Owner only** |
| **Trust** | Untrusted — passes through a validator / CI | **Fully trusted** — no sandbox, by definition can do anything on the account |
| **How it's installed** | Published through the API / catalog | `pip install` + service restart — **not** through the API |
| **Why** | Data can be checked; code cannot be safely accepted from strangers (that would be remote code execution as a feature) | The owner is the single trusted party; the API key is the bot's key |
| **Guide** | `docs/modules.md`, `docs/flow-design-guide.md` | `docs/plugins.md` |

The rule of thumb: **if it's data, anyone can publish it and the validator guards it; if it's code, only
the owner installs it, and there is no sandbox — that's a deliberate design choice, not a gap.**

---

## 7. Where to go next

- **Run it:** the [monorepo README](../README.en.md).
- **Understand *why* it's shaped this way:** [docs/WHY.en.md](WHY.en.md).
- **Extend it:** [CONTRIBUTING.en.md](../CONTRIBUTING.en.md), then the per-repo guides linked above.
- **Per-repo AI maps:** each repository's `docs/for_ai/` directory. Start with the superproject's
  [`docs/for_ai/index.md`](for_ai/index.md).
