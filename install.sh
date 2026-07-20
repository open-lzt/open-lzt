#!/usr/bin/env bash
# open-lzt one-command installer. Idempotent: safe to re-run. Brings up the whole stand on one host:
# Postgres + Redis (docker) and testnet + eventus + flow(api/worker) + mcp (systemd + uv).
#
#   sudo ./install.sh            # install / reinstall / update in place
#   sudo ./install.sh --dry-run  # print what it would do, change nothing
#
# Everything it would otherwise ask for can be given up front, and anything given is never asked
# about again:
#   --bot-token T --bot-admins 111,222   telegram admin bot
#   --domain d --email e                 public HTTPS via Let's Encrypt
#   --tls selfsigned|none                TLS without a domain / explicitly off
#   --market-mode testnet|prod           default testnet
#   --yes                                take defaults for anything still unset, never prompt
#
# Assumes Debian/Ubuntu + systemd + root. See README.md for the port map.
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
ASSUME_YES=0
ARG_BOT_TOKEN=""; ARG_BOT_ADMINS=""; ARG_DOMAIN=""; ARG_EMAIL=""; ARG_TLS=""; ARG_MARKET_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y|--non-interactive) ASSUME_YES=1; shift ;;
    --bot-token) ARG_BOT_TOKEN="${2:-}"; shift 2 ;;
    --bot-admins) ARG_BOT_ADMINS="${2:-}"; shift 2 ;;
    --domain) ARG_DOMAIN="${2:-}"; shift 2 ;;
    --email) ARG_EMAIL="${2:-}"; shift 2 ;;
    --tls) ARG_TLS="${2:-}"; shift 2 ;;
    --market-mode) ARG_MARKET_MODE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'unknown flag: %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

# One question, asked in exactly one place: may this run stop and wait for a human? A flag that
# supplied the answer, `--yes`, or a stdin that is not a terminal all mean no.
interactive() { [[ $ASSUME_YES == 0 && -t 0 && -e /dev/tty ]]; }

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

# A dry run never sources .env, so every later `$MARKET_MODE`/`$*_PORT` would trip `set -u` and
# abort the very mode whose job is to abort nothing. Sourcing .env below overrides these when it
# exists; the values here match .env.example so a dry run prints what a real run would do.
#
# `ENV_MARKET_MODE` is the exception that must survive that source. `MARKET_MODE=prod ./install.sh`
# reads as an override of the file, but `source .env` silently put the file's value back — so the
# caller asked for prod, got testnet, and every later line agreed it was fine. Captured here,
# re-applied after the source.
ENV_MARKET_MODE="${MARKET_MODE:-}"
MARKET_MODE="${MARKET_MODE:-testnet}"
TESTNET_PORT="${TESTNET_PORT:-8765}"
EVENTUS_PORT="${EVENTUS_PORT:-27543}"
FLOW_PORT="${FLOW_PORT:-8000}"
MCP_PORT="${MCP_PORT:-8770}"

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
# Precedence, most explicit first: --market-mode flag, then an inherited MARKET_MODE, then .env.
REQUESTED_MODE="${ARG_MARKET_MODE:-$ENV_MARKET_MODE}"
if [[ -n "$REQUESTED_MODE" ]]; then
  [[ "$REQUESTED_MODE" == testnet || "$REQUESTED_MODE" == prod ]] \
    || die "market mode must be testnet or prod, got '$REQUESTED_MODE'"
  MARKET_MODE="$REQUESTED_MODE"
  [[ $DRY_RUN == 0 ]] && set_kv .env MARKET_MODE "$MARKET_MODE"
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
  # `.env` is read with `source`, and bash strips the quotes out of EVENTUS_TOKENS=["tok"] — so a
  # value written exactly as .env.example documents it arrives here as [tok] and reaches the daemon
  # as invalid JSON, surfacing at boot as a SettingsError three layers from the cause. Re-quote the
  # bare elements rather than making every user learn to single-quote the line.
  if [[ "${eventus_tokens}" =~ ^\[.+\]$ && "${eventus_tokens}" != *'"'* ]]; then
    eventus_tokens="$(printf '%s' "${eventus_tokens}" \
      | sed -E 's/^\[//; s/\]$//; s/[[:space:]]//g; s/([^,]+)/"\1"/g; s/^/[/; s/$/]/')"
    info "re-quoted EVENTUS_TOKENS into valid JSON (bash 'source' had eaten the quotes)"
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

# Five sequential `uv sync` runs spend almost all their wall-clock waiting on the network, one
# project at a time, on a box with cores to spare — so they run concurrently instead. uv's cache
# and lockfiles make this safe: each project resolves its own venv, and the shared download cache
# is concurrency-safe by design. On a cold host this is the difference between ~half an hour and
# a few minutes.
sync_projects() {
  local -a projects=(
    "testnet|--project projects/testnet"
    "eventus|--project projects/eventus --extra engine"
    "eventus-sdk|--project projects/eventus-sdk"
    "flow|--project projects/flow"
    "mcp|--project projects/mcp"
  )
  local -a pids=() names=()
  local entry name args logfile
  for entry in "${projects[@]}"; do
    name="${entry%%|*}"; args="${entry#*|}"
    logfile="/tmp/open-lzt-sync-${name}.log"
    # shellcheck disable=SC2086 — args is a deliberate word-split argument list
    "$UV" sync $args >"$logfile" 2>&1 &
    pids+=("$!"); names+=("$name")
    info "syncing $name …"
  done
  local i failed=0
  for i in "${!pids[@]}"; do
    if wait "${pids[$i]}"; then
      ok "${names[$i]} synced"
    else
      failed=1
      warn "${names[$i]} FAILED — tail of /tmp/open-lzt-sync-${names[$i]}.log:"
      tail -15 "/tmp/open-lzt-sync-${names[$i]}.log" | sed 's/^/      /'
    fi
  done
  return $failed
}
if [[ $DRY_RUN == 0 ]]; then
  # More parallel downloads than the default: the bottleneck here is latency, not bandwidth.
  export UV_CONCURRENT_DOWNLOADS="${UV_CONCURRENT_DOWNLOADS:-16}"
  sync_projects || die "dependency install failed — see the logs above"
else
  info "dry-run: skipping uv sync"
fi
ok "dependencies installed"

# The panel is built from source rather than shipped as a release artifact: building from source is
# this project's trust story, and a prebuilt bundle would be one more thing to verify. The cost is a
# node/pnpm prerequisite on what used to be a Python-only host — stated in the README so it is not
# discovered here.
build_panel() {
  command -v node >/dev/null 2>&1 || { warn "node not found — panel not built (API still works)"; return 0; }
  # On a stock Debian/Ubuntu node package, `pnpm` on PATH is a corepack SHIM: it asks
  # "Do you want to continue?" before fetching the real pnpm — on EVERY invocation, not just the
  # first. Unset, that prompt hangs an unattended install forever instead of failing it, so the
  # whole panel build runs with the prompt disabled and stdin closed.
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  local pnpm_bin
  pnpm_bin="$(command -v pnpm 2>/dev/null || true)"
  if [[ -z "$pnpm_bin" ]]; then
    # corepack is the supported way to get pnpm without a global npm install, and it is bundled
    # with node — but it is not always enabled, so failing here is not fatal.
    corepack enable >/dev/null 2>&1 </dev/null \
      && pnpm_bin="$(command -v pnpm 2>/dev/null || true)"
  fi
  [[ -n "$pnpm_bin" ]] || { warn "pnpm not found — panel not built (see README prerequisites)"; return 0; }
  ( cd projects/flow/frontend \
      && "$pnpm_bin" install --frozen-lockfile --prefer-offline </dev/null \
      && "$pnpm_bin" run build </dev/null ) || { warn "panel build failed — the API is unaffected"; return 0; }
  ok "panel built"
}

# Building the panel is not serving it. `deploy/setup_tls.sh` wires nginx up for a real domain with
# a certificate, but a plain install has no domain — and without this the build sat in dist/ while
# http://<host>/ answered 403 from nginx's stock default site.
serve_panel() {
  local dist="$INSTALL_DIR/projects/flow/frontend/dist"
  [[ -f "$dist/index.html" ]] || return 0
  command -v nginx >/dev/null 2>&1 || { warn "nginx not installed — panel built but not served"; return 0; }

  mkdir -p /etc/nginx/snippets
  sed -e "s|\${PANEL_ROOT}|$dist|g" \
      -e "s|\${FLOW_PORT}|$FLOW_PORT|g" \
      -e "s|\${EVENTUS_PORT}|$EVENTUS_PORT|g" \
      "$INSTALL_DIR/deploy/nginx/panel.conf" > /etc/nginx/snippets/open-lzt-panel.conf

  cat > /etc/nginx/sites-available/open-lzt-panel <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    include snippets/open-lzt-panel.conf;
}
NGINX
  # Two `default_server` blocks on the same port is a hard nginx error, so the stock site goes.
  rm -f /etc/nginx/sites-enabled/default
  ln -sf /etc/nginx/sites-available/open-lzt-panel /etc/nginx/sites-enabled/open-lzt-panel

  if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx >/dev/null 2>&1
    ok "panel served at http://$(hostname -I 2>/dev/null | awk '{print $1}')/"
  else
    rm -f /etc/nginx/sites-enabled/open-lzt-panel
    warn "nginx rejected the panel site — left untouched, panel not served"
  fi
}

phase "4b/7 Build the panel"
if [[ $DRY_RUN == 0 ]]; then build_panel; serve_panel; else info "dry-run: skipping panel build"; fi

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
# `enable --now` starts a stopped unit and does NOTHING to a running one — so on a re-run the
# services kept serving the previous config. That made a mode switch a lie in both directions:
# `--market-mode prod` re-rendered every env file, reported success, and left the worker talking to
# the mock; the reverse would leave it on the real marketplace after a switch back to testnet.
# The installer has just rewritten EnvironmentFile= for every unit, so restarting is the only
# honest end state.
for svc in testnet eventus flow-api flow-worker mcp; do
  run "systemctl enable open-lzt-${svc}.service"
  run "systemctl restart open-lzt-${svc}.service"
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
_tok="$ARG_BOT_TOKEN"; _admins="$ARG_BOT_ADMINS"
if [[ $DRY_RUN == 0 && -z "$_tok" && -z "$(grep -m1 '^BOT_TOKEN=' .env | cut -d= -f2-)" ]] \
   && interactive; then
  printf '  Manage this stand from Telegram? Paste a bot token from @BotFather, or leave blank.\n'
  read -r -p "  Bot token [skip]: " _tok </dev/tty || _tok=""
  if [[ -n "$_tok" ]]; then
    printf '  Your numeric Telegram id (from @userinfobot). Only these ids can control the stand.\n'
    read -r -p "  Admin ids (comma-separated): " _admins </dev/tty || _admins=""
  fi
fi
if [[ $DRY_RUN == 0 && -n "$_tok" ]]; then
  if [[ -n "$_admins" ]]; then
    bash scripts/bot-bootstrap.sh --token "$_tok" --admins "$_admins" \
      || warn "bot setup had issues — see output above"
  else
    warn "a bot token without admin ids answers everyone — bot NOT started (pass --bot-admins)"
  fi
fi
[[ -f deploy/env/bot.env ]] || info "telegram bot: off — enable later with 'sudo bash scripts/bot-bootstrap.sh --token <t> --admins <ids>'"

# ---- public access / TLS ------------------------------------------------------------------------
phase "Public access & TLS (optional)"
if [[ -n "$ARG_DOMAIN" ]]; then
  DOMAIN="$ARG_DOMAIN"; LETSENCRYPT_EMAIL="$ARG_EMAIL"; TLS_MODE="${ARG_TLS:-letsencrypt}"
elif [[ -n "$ARG_TLS" ]]; then
  TLS_MODE="$ARG_TLS"
elif [[ $DRY_RUN == 0 && -z "${DOMAIN:-}" && "${TLS_MODE:-none}" == "none" ]] && interactive; then
  printf '  Expose the stand over HTTPS? Enter a domain (its DNS must point at this server), or leave blank.\n'
  read -r -p "  Domain [none]: " _dom </dev/tty || _dom=""
  if [[ -n "$_dom" ]]; then
    read -r -p "  Email for Let's Encrypt: " _email </dev/tty || _email=""
    DOMAIN="$_dom"; LETSENCRYPT_EMAIL="$_email"; TLS_MODE="letsencrypt"
  else
    read -r -p "  No domain. Install a self-signed cert on this IP instead? [y/N]: " _ss </dev/tty || _ss=""
    [[ "$_ss" =~ ^[Yy] ]] && TLS_MODE="selfsigned" || TLS_MODE="none"
  fi
fi
if [[ $DRY_RUN == 0 ]]; then
  set_kv .env DOMAIN "${DOMAIN:-}"; set_kv .env TLS_MODE "${TLS_MODE:-none}"
  set_kv .env LETSENCRYPT_EMAIL "${LETSENCRYPT_EMAIL:-}"
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
