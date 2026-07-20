#!/usr/bin/env bash
# open-lzt one-command installer. Idempotent: safe to re-run. Brings up the whole stand on one host:
# Postgres + Redis (docker) and testnet + eventus + flow(api/worker) + mcp (systemd + uv).
#
#   sudo ./install.sh            # install / reinstall / update in place
#   sudo ./install.sh --dry-run  # print what it would do, change nothing
#
# Assumes Debian/Ubuntu + systemd + root. See README.md for the port map.
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ---- pretty output ------------------------------------------------------------------------------
c_reset=$'\033[0m'; c_cyan=$'\033[1;36m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'
c_red=$'\033[1;31m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'; c_mag=$'\033[1;35m'
_rule="────────────────────────────────────────────────────────────"
banner() {
  printf '\n%s╭%s╮%s\n'   "$c_cyan" "$_rule" "$c_reset"
  printf '%s│%s  %s%-56s%s%s│%s\n' "$c_cyan" "$c_reset" "$c_bold" "open-lzt · self-hosted lzt.market stand" "$c_reset" "$c_cyan" "$c_reset"
  printf '%s│%s  %s%-56s%s%s│%s\n' "$c_cyan" "$c_reset" "$c_dim" "one-command installer" "$c_reset" "$c_cyan" "$c_reset"
  printf '%s╰%s╯%s\n'   "$c_cyan" "$_rule" "$c_reset"
}
phase() { printf '\n%s▸ %s%s\n%s%s%s\n' "$c_mag" "$*" "$c_reset" "$c_dim" "$_rule" "$c_reset"; }
ok()    { printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
info()  { printf '  %s·%s %s%s%s\n' "$c_cyan" "$c_reset" "$c_dim" "$*" "$c_reset"; }
warn()  { printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()   { printf '  %s✗ %s%s\n' "$c_red" "$*" "$c_reset" >&2; exit 1; }
run()   { if [[ $DRY_RUN == 1 ]]; then printf '   %s[dry-run] %s%s\n' "$c_dim" "$*" "$c_reset"; else eval "$@"; fi; }
set_kv() { local f="$1" k="$2" v="$3"; if grep -q "^${k}=" "$f"; then sed -i "s|^${k}=.*|${k}=${v}|" "$f"; else echo "${k}=${v}" >>"$f"; fi; }

UV=/root/.local/bin/uv
export PATH="/root/.local/bin:$PATH"

banner

# ---- 0. prerequisites ---------------------------------------------------------------------------
phase "0/7 Prerequisites (git, curl, docker, uv)"
need_apt=0
for bin in git curl; do command -v "$bin" >/dev/null || need_apt=1; done
if [[ $need_apt == 1 ]]; then
  run "apt-get update -qq && apt-get install -y -qq git curl ca-certificates"
fi
if ! command -v docker >/dev/null; then
  warn "docker not found — installing via get.docker.com"
  run "curl -fsSL https://get.docker.com | sh"
fi
docker compose version >/dev/null 2>&1 || die "docker compose plugin missing"
if ! command -v uv >/dev/null && [[ ! -x $UV ]]; then
  run "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi
# Make uv available to the non-root service user (units run as 'open-lzt', not root).
[[ -x $UV ]] && run "install -m755 $UV /usr/local/bin/uv && install -m755 ${UV%/*}/uvx /usr/local/bin/uvx 2>/dev/null || true"
# Dedicated unprivileged system user for the services.
run "id open-lzt >/dev/null 2>&1 || useradd --system --home-dir $INSTALL_DIR --shell /usr/sbin/nologin open-lzt"
ok "prerequisites present"

# ---- 1. config ----------------------------------------------------------------------------------
phase "1/7 Config (.env + generated secrets)"
cd "$INSTALL_DIR"
[[ -f .env ]] || run "cp .env.example .env"
# shellcheck disable=SC1091
[[ $DRY_RUN == 0 ]] && set -a && source .env && set +a

# Fernet key == urlsafe-base64 of 32 random bytes; generate without importing cryptography.
gen_fernet() { openssl rand -base64 32 | tr '+/' '-_'; }
gen_hex()    { openssl rand -hex 32; }
ensure_secret() { # var-name generator
  local name="$1" gen="$2" cur="${!1:-}"
  if [[ -z "$cur" ]]; then
    [[ $DRY_RUN == 1 ]] && { printf '   [dry-run] would generate %s\n' "$name"; return; }
    local val; val="$($gen)"
    if grep -q "^${name}=" .env; then sed -i "s|^${name}=.*|${name}=${val}|" .env; else echo "${name}=${val}" >>.env; fi
    export "${name}=${val}"
    ok "generated $name"
  fi
}
if [[ $DRY_RUN == 0 ]]; then
  ensure_secret POSTGRES_PASSWORD gen_hex
  ensure_secret REDIS_PASSWORD gen_hex
  ensure_secret FLOW_MASTER_KEY gen_fernet
  ensure_secret EVENTUS_TOKEN_ENC_KEY gen_fernet
  ensure_secret FLOW_API_KEY gen_hex
  ensure_secret EVENTUS_ADMIN_API_KEY gen_hex
  set -a && source .env && set +a
  chmod 600 .env
fi
ok "config ready (MARKET_MODE=${MARKET_MODE:-testnet})"

# ---- 2. infra -----------------------------------------------------------------------------------
phase "2/7 Infra (Postgres + Redis via docker compose)"
run "docker compose up -d"
if [[ $DRY_RUN == 0 ]]; then
  # Wait for the container's own healthcheck — pg_isready alone races the first-boot restart
  # (initdb briefly starts then restarts postgres, so a lone probe can pass mid-init).
  for _ in $(seq 1 60); do
    [[ "$(docker inspect -f '{{.State.Health.Status}}' open-lzt-postgres-1 2>/dev/null)" == healthy ]] && break
    sleep 2
  done
  # second logical DB for eventus (compose creates POSTGRES_DB=lztflow only); retry over the
  # short window where the socket may still be flapping.
  for _ in $(seq 1 15); do
    if docker compose exec -T postgres psql -U "${POSTGRES_USER:-lzt}" -tc \
         "SELECT 1 FROM pg_database WHERE datname='lzteventus'" 2>/dev/null | grep -q 1; then break; fi
    docker compose exec -T postgres createdb -U "${POSTGRES_USER:-lzt}" lzteventus 2>/dev/null && break
    sleep 2
  done
fi
ok "postgres + redis up (DBs: lztflow, lzteventus)"

# ---- 3. render per-service env files ------------------------------------------------------------
phase "3/7 Render per-service env files (deploy/env/*.env)"
install -d -m700 deploy/env   # secrets live here — dir + files locked to owner
render_envs() {
  local pg="postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}"
  local pg_sync="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}"
  # The password travels in the URL because that is the only channel redis-py/arq accept. It
  # never reaches a process list: these files are 0600 and read as EnvironmentFile= by systemd.
  local redis="redis://:${REDIS_PASSWORD}@127.0.0.1:${REDIS_PORT}"
  local testnet_url=""
  [[ "${MARKET_MODE}" == "testnet" ]] && testnet_url="http://127.0.0.1:${TESTNET_PORT}"
  # The eventus engine builds an lztforge Client eagerly at boot and refuses an empty token list.
  # In testnet mode a placeholder token is enough (the mock accepts any bearer).
  local eventus_tokens="${EVENTUS_TOKENS}"
  if [[ "${MARKET_MODE}" == "testnet" && ( -z "${eventus_tokens}" || "${eventus_tokens}" == "[]" ) ]]; then
    eventus_tokens='["testnet-fake-token"]'
  fi

  cat > deploy/env/testnet.env <<EOF
LZT_TESTNET_HOST=127.0.0.1
LZT_TESTNET_PORT=${TESTNET_PORT}
EOF

  cat > deploy/env/eventus.env <<EOF
LZT_DATABASE_URL=${pg_sync}/lzteventus
LZT_REDIS_URL=${redis}/1
LZT_ADMIN_API_KEY=${EVENTUS_ADMIN_API_KEY}
LZT_TOKEN_ENC_KEY=${EVENTUS_TOKEN_ENC_KEY}
LZT_TOKENS=${eventus_tokens}
LZT_API_BASE_URL=${testnet_url}
LZT_HEALTH_HOST=127.0.0.1
LZT_HEALTH_PORT=${EVENTUS_PORT}
EOF

  # flow: its own LZT_FLOW_*. The worker does NOT embed the eventus engine (LZT_FLOW_EMBED_EVENTUS=0)
  # — eventus runs as its own service (open-lzt-eventus) and holds the poll advisory lock, so an
  # embedded engine here would only block forever on that lock (and pylzt rejects the empty token
  # list this stand runs with). The LZT_* below are kept for reference; unused while EMBED_EVENTUS=0.
  cat > deploy/env/flow.env <<EOF
LZT_FLOW_DATABASE_URL=${pg}/lztflow
LZT_FLOW_REDIS_URL=${redis}/0
LZT_FLOW_MASTER_KEY=${FLOW_MASTER_KEY}
LZT_FLOW_API_KEY=${FLOW_API_KEY}
LZT_FLOW_MARKET_BASE_URL=${testnet_url}
LZT_FLOW_DEFAULT_TENANT_ID=${DEFAULT_TENANT_ID}
LZT_FLOW_EMBED_EVENTUS=0
LZT_DATABASE_URL=${pg_sync}/lzteventus
LZT_REDIS_URL=${redis}/2
LZT_TOKEN_ENC_KEY=${EVENTUS_TOKEN_ENC_KEY}
LZT_TOKENS=[]
LZT_ADMIN_API_KEY=${EVENTUS_ADMIN_API_KEY}
LZT_API_BASE_URL=${testnet_url}
EOF

  cat > deploy/env/mcp.env <<EOF
LZT_DEV_MCP_TESTNET_BASE_URL=${testnet_url}
LZT_DEV_MCP_LZT_FLOW_BASE_URL=http://127.0.0.1:${FLOW_PORT}
LZT_DEV_MCP_LZT_FLOW_API_KEY=${FLOW_API_KEY}
LZT_DEV_MCP_LZT_EVENTUS_BASE_URL=http://127.0.0.1:${EVENTUS_PORT}
LZT_DEV_MCP_LZT_EVENTUS_ADMIN_API_KEY=${EVENTUS_ADMIN_API_KEY}
EOF
}
if [[ $DRY_RUN == 0 ]]; then render_envs; chmod 600 deploy/env/*.env; fi
ok "env files rendered (testnet_url=${MARKET_MODE})"

# ---- 4. dependencies ----------------------------------------------------------------------------
phase "4/7 Install project dependencies (uv sync)"
# The tree is chowned to the 'open-lzt' user at the end; on a re-run these git ops run as root over
# an open-lzt-owned repo, so mark it trusted (also needed by update.sh / autoupdate.sh).
git config --global --get-all safe.directory 2>/dev/null | grep -qx "$INSTALL_DIR" \
  || git config --global --add safe.directory "$INSTALL_DIR"
for d in "$INSTALL_DIR"/projects/*/; do git config --global --add safe.directory "${d%/}" 2>/dev/null || true; done
# projects/* are git submodules — populate them if the repo was cloned without --recurse-submodules.
[[ -f .gitmodules ]] && run "git submodule update --init --recursive"
run "$UV sync --project projects/testnet"
run "$UV sync --project projects/eventus --extra engine"
run "$UV sync --project projects/flow"
run "$UV sync --project projects/mcp"
ok "dependencies installed"

# The panel is built from source rather than shipped as a release artifact: building from source is
# this project's trust story, and a prebuilt bundle would be one more thing to verify. The cost is a
# node/pnpm prerequisite on what used to be a Python-only host — stated in the README so it is not
# discovered here.
build_panel() {
  command -v node >/dev/null 2>&1 || { warn "node not found — panel not built (API still works)"; return 0; }
  local pnpm_bin
  pnpm_bin="$(command -v pnpm 2>/dev/null || true)"
  if [[ -z "$pnpm_bin" ]]; then
    # corepack is the supported way to get pnpm without a global npm install, and it is bundled
    # with node — but it is not always enabled, so failing here is not fatal.
    corepack enable >/dev/null 2>&1 && pnpm_bin="$(command -v pnpm 2>/dev/null || true)"
  fi
  [[ -n "$pnpm_bin" ]] || { warn "pnpm not found — panel not built (see README prerequisites)"; return 0; }
  ( cd projects/flow/frontend \
      && "$pnpm_bin" install --frozen-lockfile --prefer-offline \
      && "$pnpm_bin" run build ) || { warn "panel build failed — the API is unaffected"; return 0; }
  ok "panel built"
}
phase "4b/7 Build the panel"
if [[ $DRY_RUN == 0 ]]; then build_panel; else info "dry-run: skipping panel build"; fi

# ---- 5. migrations (two separate alembic chains) ------------------------------------------------
phase "5/7 Database migrations"
# DSNs are read from the 0600 per-service env files, not passed inline — keeps the DB password
# out of the process command line (ps).
if [[ $DRY_RUN == 0 ]]; then
  ( set -a; . "$INSTALL_DIR/deploy/env/eventus.env"; set +a
    LZT_DATABASE_URL="${LZT_DATABASE_URL/postgresql:/postgresql+asyncpg:}"
    cd projects/eventus && "$UV" run alembic upgrade head ) && ok "eventus migrated"
  ( set -a; . "$INSTALL_DIR/deploy/env/flow.env"; set +a
    cd projects/flow && "$UV" run alembic upgrade head ) && ok "flow migrated"
else
  warn "dry-run: skipping migrations"
fi
# Hand the whole tree to the unprivileged service user before the units start.
run "chown -R open-lzt:open-lzt '$INSTALL_DIR'"

# ---- 6. systemd services ------------------------------------------------------------------------
phase "6/7 systemd services"
run "install -m644 deploy/systemd/open-lzt-*.service /etc/systemd/system/"
run "install -m644 deploy/systemd/open-lzt-*.timer /etc/systemd/system/"
run "systemctl daemon-reload"
for svc in testnet eventus flow-api flow-worker mcp; do
  run "systemctl enable --now open-lzt-${svc}.service"
done
# The bot is deliberately NOT in that list: without a token and an admin list it would crash-loop,
# and with a token but no admin list it would answer everyone. scripts/bot-bootstrap.sh enables it
# once it has both.
ok "services enabled + started"
# Auto-update is installed but OFF by default — enable per docs/AUTOUPDATE.md.
info "auto-update installed (disabled): enable with 'systemctl enable --now open-lzt-autoupdate.timer'"

# ---- 7. health ----------------------------------------------------------------------------------
phase "7/7 Health check"
if [[ $DRY_RUN == 0 ]]; then
  # Services take longer than a couple of seconds to bind (eventus opens DB+Redis+poller). Retry
  # for ~40s before reporting, instead of a single early probe.
  for _ in $(seq 1 20); do
    bash scripts/healthcheck.sh >/dev/null 2>&1 && break
    sleep 2
  done
  bash scripts/healthcheck.sh || warn "some services not healthy yet — check: journalctl -u open-lzt-<svc>"
fi
ok "install complete"

# ---- telegram bot (optional) ---------------------------------------------------------------------
phase "Telegram admin bot (optional)"
if [[ $DRY_RUN == 0 && -z "$(grep -m1 '^BOT_TOKEN=' .env | cut -d= -f2-)" && -e /dev/tty ]]; then
  printf '  Manage this stand from Telegram? Paste a bot token from @BotFather, or leave blank.
'
  read -r -p "  Bot token [skip]: " _tok </dev/tty || _tok=""
  if [[ -n "$_tok" ]]; then
    printf '  Your numeric Telegram id (from @userinfobot). Only these ids can control the stand.
'
    read -r -p "  Admin ids (comma-separated): " _admins </dev/tty || _admins=""
    if [[ -n "$_admins" ]]; then
      bash scripts/bot-bootstrap.sh --token "$_tok" --admins "$_admins"         || warn "bot setup had issues — see output above"
    else
      warn "no admin ids given — bot NOT started (a bot with no admins answers everyone)"
    fi
  fi
fi
[[ -f deploy/env/bot.env ]] || info "telegram bot: off — enable later with 'sudo bash scripts/bot-bootstrap.sh --token <t> --admins <ids>'"

# ---- public access / TLS ------------------------------------------------------------------------
phase "Public access & TLS (optional)"
if [[ $DRY_RUN == 0 && -z "${DOMAIN:-}" && "${TLS_MODE:-none}" == "none" && -e /dev/tty ]]; then
  printf '  Expose the stand over HTTPS? Enter a domain (its DNS must point at this server), or leave blank.\n'
  read -r -p "  Domain [none]: " _dom </dev/tty || _dom=""
  if [[ -n "$_dom" ]]; then
    read -r -p "  Email for Let's Encrypt: " _email </dev/tty || _email=""
    DOMAIN="$_dom"; LETSENCRYPT_EMAIL="$_email"; TLS_MODE="letsencrypt"
  else
    read -r -p "  No domain. Install a self-signed cert on this IP instead? [y/N]: " _ss </dev/tty || _ss=""
    [[ "$_ss" =~ ^[Yy] ]] && TLS_MODE="selfsigned" || TLS_MODE="none"
  fi
  set_kv .env DOMAIN "${DOMAIN:-}"; set_kv .env TLS_MODE "$TLS_MODE"; set_kv .env LETSENCRYPT_EMAIL "${LETSENCRYPT_EMAIL:-}"
fi
if [[ $DRY_RUN == 0 && "${TLS_MODE:-none}" != "none" ]]; then
  EVENTUS_PORT="${EVENTUS_PORT}" bash deploy/setup_tls.sh "${DOMAIN:-}" "${LETSENCRYPT_EMAIL:-}" "${TLS_MODE}" "${FLOW_PORT}" \
    || warn "TLS setup had issues — see output above"
else
  info "public access: loopback only (no TLS) — re-run install to set a domain / self-signed cert"
fi

# ---- summary box --------------------------------------------------------------------------------
svc_line() { # name port
  local state; state=$(systemctl is-active "open-lzt-$1" 2>/dev/null || echo unknown)
  local dot="$c_green●$c_reset"; [[ "$state" == active ]] || dot="$c_red●$c_reset"
  printf '%s│%s  %s %-13s %sport %-6s%s%s%s\n' \
    "$c_cyan" "$c_reset" "$dot" "$1" "$c_bold" "$2" "$c_reset" "$c_dim" "$state$c_reset"
}
printf '\n%s╭%s╮%s\n' "$c_cyan" "$_rule" "$c_reset"
printf '%s│%s  %sopen-lzt is up%s  %s(MARKET_MODE=%s)%s\n' \
  "$c_cyan" "$c_reset" "$c_green$c_bold" "$c_reset" "$c_dim" "${MARKET_MODE:-testnet}" "$c_reset"
printf '%s├%s┤%s\n' "$c_cyan" "$_rule" "$c_reset"
svc_line testnet     "${TESTNET_PORT}"
svc_line eventus     "${EVENTUS_PORT}"
svc_line flow-api    "${FLOW_PORT}"
svc_line flow-worker "-"
svc_line mcp         "${MCP_PORT}"
printf '%s├%s┤%s\n' "$c_cyan" "$_rule" "$c_reset"
if [[ "${TLS_MODE:-none}" != "none" ]]; then
  printf '%s├%s┤%s\n' "$c_cyan" "$_rule" "$c_reset"
  printf '%s│%s  %sPublic:%s https://%s\n' "$c_cyan" "$c_reset" "$c_green$c_bold" "$c_reset" "${DOMAIN:-<this-ip>}"
fi
printf '%s├%s┤%s\n' "$c_cyan" "$_rule" "$c_reset"
printf '%s│%s  %sManage:%s update.sh · scripts/healthcheck.sh · scripts/smoke.sh\n' \
  "$c_cyan" "$c_reset" "$c_dim" "$c_reset"
printf '%s╰%s╯%s\n' "$c_cyan" "$_rule" "$c_reset"

# ---- next steps ---------------------------------------------------------------------------------
h() { printf '\n%s%s%s\n' "$c_mag$c_bold" "$*" "$c_reset"; }
cmd() { printf '  %s$%s %s\n' "$c_green" "$c_reset" "$*"; }
note() { printf '    %s%s%s\n' "$c_dim" "$*" "$c_reset"; }

printf '\n%s%s─── next steps ──────────────────────────────────────────%s\n' "$c_cyan" "$c_bold" "$c_reset"
note "All ports bind to 127.0.0.1. From your laptop, tunnel first:"
cmd "ssh -N -L 8000:127.0.0.1:8000 -L 27543:127.0.0.1:27543 -L 8765:127.0.0.1:8765 root@<server>"

h "Interactive API docs (through the tunnel)"
note "eventus  http://127.0.0.1:${EVENTUS_PORT}/scalar   (OpenAPI)   ·   /docs (Swagger)"
note "flow     http://127.0.0.1:${FLOW_PORT}/docs"

h "Poke the running stand"
cmd "curl -s http://127.0.0.1:${FLOW_PORT}/catalog/list -H \"X-API-Key: \$(grep ^FLOW_API_KEY= .env|cut -d= -f2)\""
note "list every flow node type the editor offers"
cmd "curl -s http://127.0.0.1:${EVENTUS_PORT}/subscriptions -H \"Authorization: Bearer \$(grep ^EVENTUS_ADMIN_API_KEY= .env|cut -d= -f2)\""
note "list event subscriptions"

h "Create a subscription (eventus — poll new lots on a category)"
cat <<EOF
  ${c_green}\$${c_reset} EV_KEY=\$(grep ^EVENTUS_ADMIN_API_KEY= .env | cut -d= -f2)
  ${c_green}\$${c_reset} curl -s -X POST http://127.0.0.1:${EVENTUS_PORT}/subscriptions \\
       -H "Authorization: Bearer \$EV_KEY" -H "Content-Type: application/json" \\
       -d '{"transport":"polling","event_type":"new_lot","scope":{"kind":"category","category":"steam"}}'
EOF
note "exact field names: open /scalar above — it is generated from the live schema"

h "Create & run a flow"
note "Draw it on the canvas (flow frontend), or drive it from an AI agent over the MCP server"
note "(tools: create_flow · compile_flow · create_run · get_run_trace · create_subscription)."
cmd "MARKET_MODE=testnet means every call hits the mock — no real money, no real token."

h "Docs & source"
note "monorepo   https://github.com/zlexdev/open-lzt        (README · docs/AUTOUPDATE.md)"
note "projects   /pylzt(lztforge) /lzt-testnet /lzt-eventus /lzt-flow /lzt-mcp under github.com/zlexdev"
printf '\n'
