# open-lzt — AI-agent map

Compressed orientation for an AI agent working in this monorepo. Read this before grepping source.

## Layout

```
open-lzt/
├─ install.sh / update.sh        # one-command stand lifecycle (see README "Operations")
├─ docker-compose.yml            # infra only: postgres + redis
├─ .env.example                  # canonical config; install.sh renders deploy/env/<svc>.env from it
├─ deploy/systemd/               # 5 unit files, one per service
├─ scripts/{smoke,healthcheck}.sh
└─ projects/
   ├─ pylzt/       # market/forum/antipublic async SDK (successor to lztforge)
   ├─ testnet/     # mock lzt.market server (FastAPI) — the test double
   ├─ eventus/     # event engine service (REST :27543 + poller + PG/Redis)
   ├─ flow/        # flow-automation service (API :8000 + arq worker + frontend)
   ├─ mcp/         # MCP server for AI agents (stdio / http :8770)
   └─ eventus-sdk/ # client library for the eventus engine
```

## Key facts

- **Client naming**: consumers `import lztforge`; it is a shim re-exporting `pylzt`
  (`projects/pylzt/src/lztforge/`, runtime MetaPathFinder + `.pyi` stubs). Full rename is backlogged.
- **Testnet wiring**: `MARKET_MODE=testnet` points every consumer at the in-stand mock —
  mcp `LZT_DEV_MCP_TESTNET_BASE_URL`, eventus `LZT_API_BASE_URL`, flow `LZT_FLOW_MARKET_BASE_URL`.
  Both the market and forum hosts are overridden so forum-scoped methods never leak to prod.
- **Config isolation**: flow uses `LZT_FLOW_*`; eventus (and flow's embedded engine) use `LZT_*`.
  install.sh renders a separate `deploy/env/<svc>.env` per service so the `LZT_` prefix never collides.
- Per-project internals: each `projects/<x>/docs/for_ai/` and `_MODULE.md` files.

## Where to look

- Install, port map, operations → `README.md`.
- Per-service internals → `projects/<x>/docs/for_ai/`, `projects/<x>/_MODULE.md`.
