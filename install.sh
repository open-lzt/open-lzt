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
#   --tls selfsigned|none                force self-signed on a bare IP (the default), or opt out
#   --market-mode testnet|prod           default testnet
#   --yes                                take defaults for anything still unset, never prompt
#
# Assumes Debian/Ubuntu + systemd + root. See README.md for the port map.
set -euo pipefail

# ---- pretty output ------------------------------------------------------------------------------
c_reset=$'\033[0m'; c_cyan=$'\033[1;36m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'
c_red=$'\033[1;31m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'; c_mag=$'\033[1;35m'
_rule="────────────────────────────────────────────────────────────"
# `printf %-56s` pads by BYTES, so one multibyte glyph in the text loses a column and the right
# edge of the box drifts inward. The visible width is passed in rather than measured, because
# measuring it needs a UTF-8 locale that a fresh server does not reliably have.
_box() {
  printf '%s│%s  %s%s%s%*s%s│%s\n' \
    "$c_cyan" "$c_reset" "$2" "$1" "$c_reset" "$(( 56 - $3 ))" "" "$c_cyan" "$c_reset"
}
banner() {
  # The bootstrap prints this and then exec's this same script from the clone; without a
  # marker the installer would greet you twice in one run.
  [[ -n "${OPEN_LZT_BANNER_SHOWN:-}" ]] && return 0
  export OPEN_LZT_BANNER_SHOWN=1
  printf '\n%s╭%s╮%s\n'   "$c_cyan" "$_rule" "$c_reset"
  _box "open-lzt · self-hosted lzt.market stand" "$c_bold" 39
  _box "one-command installer"                   "$c_dim"  21
  printf '%s╰%s╯%s\n'   "$c_cyan" "$_rule" "$c_reset"
}
phase() { printf '\n%s▸ %s%s\n%s%s%s\n' "$c_mag" "$*" "$c_reset" "$c_dim" "$_rule" "$c_reset"; }
ok()    { printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
info()  { printf '  %s·%s %s%s%s\n' "$c_cyan" "$c_reset" "$c_dim" "$*" "$c_reset"; }
warn()  { printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()   { printf '  %s✗ %s%s\n' "$c_red" "$*" "$c_reset" >&2; exit 1; }
_has_flag() {  # $1 = flag to look for; the rest are the script's own args
  local want="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bot-token|--bot-admins|--domain|--email|--tls|--market-mode) shift 2 || return 1 ;;
      "$want") return 0 ;;
      *) shift ;;
    esac
  done
  return 1
}
# ---- bootstrap: make `curl -sSL .../get/all.sh | sudo bash -s -- ...` work ----------------------
# Everything below assumes it is running from inside the checkout ($INSTALL_DIR/projects,
# deploy/env, git submodules). Curled, there is no such directory: piped to stdin BASH_SOURCE is
# not a path at all, and under `bash <(curl ...)` it is /dev/fd/63 — a pipe, not a file. So the
# test is "am I a real file inside a real checkout", never "what does dirname say".
#
# The documented form is a PIPE, not process substitution. `sudo bash <(curl ...)` cannot work:
# sudo closes the file descriptors it inherits, so /dev/fd/63 is already gone by the time bash
# opens it and the run dies with "No such file or directory".
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" && -f "$SELF" ]]; then
  INSTALL_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
  INSTALL_DIR=""
fi

OPEN_LZT_REPO="${OPEN_LZT_REPO:-https://github.com/open-lzt/open-lzt.git}"
OPEN_LZT_DIR="${OPEN_LZT_DIR:-/opt/open-lzt}"

if [[ -z "$INSTALL_DIR" || ! -f "$INSTALL_DIR/docker-compose.yml" || ! -d "$INSTALL_DIR/projects" ]]; then
  # `--dry-run` promises to change nothing, and cloning is a change. With a tree already on disk
  # there is nothing to write, so hand straight over to it; without one, say what would happen and
  # stop, rather than quietly writing 8 submodules under the flag that forbids writing.
  # Asking what the flags are must not require root, and the bootstrap runs before they are
  # parsed. A substring scan of "$*" also matched a flag's VALUE, so `--email -h` printed help
  # and skipped the whole install; this walks the args and steps over values.
  if _has_flag --help "$@" || _has_flag -h "$@"; then
    printf 'open-lzt · установка стенда одной командой\n\n'
    printf '  curl -sSL https://open-lzt.dev/get/all.sh | sudo bash -s -- --yes\n\n'
    printf 'Флаги передаются после --:\n'
    printf '  --market-mode testnet|prod     режим рынка, по умолчанию testnet\n'
    printf '  --tls selfsigned|none          сертификат на голом IP\n'
    printf '  --domain d --email e           публичный HTTPS через Let'"'"'s Encrypt\n'
    printf '  --bot-token T --bot-admins ID  телеграм-бот администратора\n'
    printf '  --yes                          ничего не спрашивать\n'
    printf '  --dry-run                      показать план, ничего не менять\n'
    exit 0
  fi

  if _has_flag --dry-run "$@" && [[ -d "$OPEN_LZT_DIR/.git" ]]; then
    exec bash "$OPEN_LZT_DIR/install.sh" "$@"
  fi
  if _has_flag --dry-run "$@"; then
    banner
    phase "Пробный запуск · дерева на диске ещё нет"
    info "склонировал бы $OPEN_LZT_REPO в $OPEN_LZT_DIR"
    info "затем запустил бы его install.sh с флагами: ${*:-без флагов}"
    warn "сам установщик пробно прогнать нечем — сначала нужно дерево:"
    printf '      %sgit clone --recursive %s %s%s\n' "$c_dim" "$OPEN_LZT_REPO" "$OPEN_LZT_DIR" "$c_reset"
    printf '      %ssudo %s/install.sh --dry-run%s\n' "$c_dim" "$OPEN_LZT_DIR" "$c_reset"
    exit 0
  fi

  [[ $EUID -eq 0 ]] || {
    printf '  %s✗ нужны права root%s\n' "$c_red" "$c_reset" >&2
    printf '    %scurl -sSL https://open-lzt.dev/get/all.sh | sudo bash -s -- --yes%s\n' "$c_dim" "$c_reset" >&2
    exit 1
  }

  banner
  phase "Загрузка · монорепозиторий open-lzt"
  command -v git >/dev/null 2>&1 || { info "ставлю git"; apt-get update -qq && apt-get install -y -qq git; }

  if [[ -d "$OPEN_LZT_DIR/.git" ]]; then
    info "дерево уже есть — обновляю $OPEN_LZT_DIR"
    git config --global --add safe.directory "$OPEN_LZT_DIR" 2>/dev/null || true
    git -C "$OPEN_LZT_DIR" fetch --prune -q origin
    git -C "$OPEN_LZT_DIR" reset --hard -q origin/HEAD
    git -C "$OPEN_LZT_DIR" submodule update --init --recursive -q
    ok "обновлено до $(git -C "$OPEN_LZT_DIR" log --oneline -1)"
  else
    info "клонирую в $OPEN_LZT_DIR — это 8 субмодулей, займёт минуту"
    mkdir -p "$(dirname "$OPEN_LZT_DIR")"
    git clone --recursive -q "$OPEN_LZT_REPO" "$OPEN_LZT_DIR" \
      || die "не удалось склонировать $OPEN_LZT_REPO"
    ok "склонировано: $(git -C "$OPEN_LZT_DIR" log --oneline -1)"
  fi

  info "передаю управление $OPEN_LZT_DIR/install.sh"
  exec bash "$OPEN_LZT_DIR/install.sh" "$@"
fi

DRY_RUN=0
ASSUME_YES=0
ARG_BOT_TOKEN=""; ARG_BOT_ADMINS=""; ARG_DOMAIN=""; ARG_EMAIL=""; ARG_TLS=""; ARG_MARKET_MODE=""

# `shift 2` on a trailing flag fails with "shift count out of range" and `set -e` ends the run
# with a bare exit 1 — no message, nothing to act on. Refuse before the shift instead.
need_val() {
  [[ -n "${2:-}" && "${2:0:1}" != "-" ]] || die "флаг $1 требует значение"
  printf '%s' "$2"
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y|--non-interactive) ASSUME_YES=1; shift ;;
    --bot-token) ARG_BOT_TOKEN="$(need_val "$1" "${2:-}")"; shift 2 ;;
    --bot-admins) ARG_BOT_ADMINS="$(need_val "$1" "${2:-}")"; shift 2 ;;
    --domain) ARG_DOMAIN="$(need_val "$1" "${2:-}")"; shift 2 ;;
    --email) ARG_EMAIL="$(need_val "$1" "${2:-}")"; shift 2 ;;
    --tls) ARG_TLS="$(need_val "$1" "${2:-}")"; shift 2 ;;
    --market-mode) ARG_MARKET_MODE="$(need_val "$1" "${2:-}")"; shift 2 ;;
    -h|--help)
      if [[ -n "$SELF" && -f "$SELF" ]]; then sed -n '2,16p' "$SELF" | sed 's/^# \{0,1\}//'
      else printf 'curl -sSL https://open-lzt.dev/get/all.sh | sudo bash -s -- --yes\n'; fi
      exit 0 ;;
    *) printf 'unknown flag: %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

# One question, asked in exactly one place: may this run stop and wait for a human? A flag that
# supplied the answer, `--yes`, or a stdin that is not a terminal all mean no.
interactive() { [[ $ASSUME_YES == 0 && -t 0 && -e /dev/tty ]]; }

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
phase "0/7 Зависимости (git, curl, openssl, docker, uv, node, pnpm)"

# Everything this installer shells out to, installed here rather than checked here. A missing
# tool discovered in phase 4 leaves half a stand behind; the same tool installed in phase 0 costs
# a package. `apt-get update` runs at most once, however many packages turn out to be missing.
export DEBIAN_FRONTEND=noninteractive
_apt_updated=0

# A fresh VPS runs unattended-upgrades/apt-daily in its first minutes and holds the dpkg lock.
# Without a wait, whichever phase lands in that window dies on "Could not get lock" — it took
# out nginx setup on a box where everything else had already installed fine. Waiting IS the
# fix: the background job finishes on its own.
# `apt-get` fails instantly when the dpkg lock is held (unlike `apt`, which waits 120s), and a
# fresh VPS runs unattended-upgrades for its first minutes. A wrapper would only cover OUR
# calls — get.docker.com and the NodeSource script run their own apt and are just as exposed.
# One config drop-in covers every apt in the run, ours and theirs.
apt_wait_setup() {
  local f=/etc/apt/apt.conf.d/99-open-lzt-lock-timeout
  [[ -w /etc/apt/apt.conf.d ]] || return 0
  echo "DPkg::Lock::Timeout \"${APT_WAIT:-600}\";" > "$f" 2>/dev/null || true
}
apt_install() {
  info "пакеты: $*"
  (( DRY_RUN )) && return 0
  (( _apt_updated )) || { apt-get update -qq || true; _apt_updated=1; }
  apt-get install -y -qq "$@" >/dev/null 2>&1 \
    || die "не удалось поставить: $* (попробуй вручную: apt-get install $*)"
}

apt_wait_setup
want_apt=()
for pair in git:git curl:curl openssl:openssl; do
  command -v "${pair%%:*}" >/dev/null 2>&1 || want_apt+=("${pair##*:}")
done
[[ -f /etc/ssl/certs/ca-certificates.crt ]] || want_apt+=(ca-certificates)
# Not `(( ... )) && apt_install`: with nothing to install the arithmetic returns 1, and under
# `set -e` that ends the run on the happy path.
if (( ${#want_apt[@]} )); then apt_install "${want_apt[@]}"; fi

if ! command -v docker >/dev/null; then
  info "docker не найден — ставлю через get.docker.com"
  run "curl -fsSL https://get.docker.com | sh"
fi

# A host can have `docker` and no `docker compose`: Ubuntu's own docker.io package ships without
# the plugin, and get.docker.com does nothing when some docker is already installed. Dying here
# used to hand the operator a dead end on an otherwise fine box, so install it instead. The
# package name differs per distro, hence the list before falling back to the official installer.
if ! docker compose version >/dev/null 2>&1; then
  if (( DRY_RUN )); then
    warn "плагина docker compose нет — доставил бы его"
  else
    info "docker есть, плагина compose нет — доставляю"
    apt-get update -qq || true
    for pkg in docker-compose-plugin docker-compose-v2; do
      apt-get install -y -qq "$pkg" >/dev/null 2>&1 && break || true
    done
    if ! docker compose version >/dev/null 2>&1; then
      info "в репозиториях системы плагина нет — ставлю docker-ce с get.docker.com"
      curl -fsSL https://get.docker.com | sh
    fi
    docker compose version >/dev/null 2>&1 \
      || die "docker compose не установился — поставь вручную: apt-get install docker-compose-plugin"
    ok "docker compose $(docker compose version --short 2>/dev/null || echo 'установлен')"
  fi
fi

# compose needs a running daemon, and a package install does not always leave one behind.
if ! (( DRY_RUN )) && ! docker info >/dev/null 2>&1; then
  info "демон docker не отвечает — запускаю"
  systemctl enable --now docker >/dev/null 2>&1 || true
  docker info >/dev/null 2>&1 || die "демон docker не поднялся — смотри: systemctl status docker"
fi
if ! command -v uv >/dev/null && [[ ! -x $UV ]]; then
  info "ставлю uv"
  run "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# node + pnpm for the panel. These used to be optional — a missing node only warned, and the box
# came up with a working API and no UI, which reads as a broken install to whoever asked for the
# panel. The distro package lags the requirement (24.04 still ships node 18), so take NodeSource.
#
# Node 22, not 20: current pnpm needs >= 22.13 and dies on `node:sqlite` under 20. Nailing the
# runtime to an old major while the package manager floats to `@latest` IS the mismatch.
NODE_MAJOR="${NODE_MAJOR:-22}"
node_major=0
command -v node >/dev/null 2>&1 && node_major="$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')"
if (( node_major < NODE_MAJOR )); then
  if (( DRY_RUN )); then
    info "поставил бы node $NODE_MAJOR (сейчас: ${node_major:-нет})"
  else
    info "ставлю node $NODE_MAJOR — панель собирается из исходников"
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - >/dev/null 2>&1 \
      || warn "репозиторий NodeSource недоступен — пробую системный пакет"
    apt-get install -y -qq nodejs >/dev/null 2>&1 || true
    command -v node >/dev/null 2>&1 || warn "node не установился — панель собрана не будет"
  fi
fi

# corepack ships with node and is the supported way to get pnpm; a global npm install would fight
# the distro package. The download prompt is disabled here for the same reason build_panel does
# it: unset, it waits for an answer nobody is there to give.
if ! command -v pnpm >/dev/null 2>&1 && command -v corepack >/dev/null 2>&1; then
  if (( DRY_RUN )); then
    info "включил бы corepack и поставил pnpm"
  else
    info "ставлю pnpm через corepack"
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack enable >/dev/null 2>&1 </dev/null || true
    # No `pnpm@latest`. corepack reads `packageManager` from the project's package.json and fetches
    # exactly that version — the project's own choice, already known to work with its lockfile.
    # `@latest` overrode it with whatever shipped today, which is how a pnpm requiring node >= 22.13
    # landed on a node 20 box and died on `node:sqlite`. Choose only when the project pins nothing,
    # and then a major that still supports the node we installed.
    if ! command -v pnpm >/dev/null 2>&1; then
      COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack prepare pnpm@9 --activate >/dev/null 2>&1 </dev/null \
        || warn "pnpm не подготовился — панель может не собраться"
    fi
  fi
fi
# Make uv available to the non-root service user (units run as 'open-lzt', not root).
[[ -x $UV ]] && run "install -m755 $UV /usr/local/bin/uv && install -m755 ${UV%/*}/uvx /usr/local/bin/uvx 2>/dev/null || true"
# Dedicated unprivileged system user for the services.
run "id open-lzt >/dev/null 2>&1 || useradd --system --home-dir $INSTALL_DIR --shell /usr/sbin/nologin open-lzt"

if (( DRY_RUN )); then
  ok "зависимости проверены"
else
  # Say what is actually on the box, not that a list of commands returned 0 — the versions are
  # the first thing anyone asks for when a later phase misbehaves.
  info "docker $(docker --version 2>/dev/null | sed 's/Docker version //;s/,.*//' || echo '—') · compose $(docker compose version --short 2>/dev/null || echo '—')"
  info "node $(node -v 2>/dev/null || echo '—') · pnpm $(pnpm --version 2>/dev/null || echo '—') · uv $(uv --version 2>/dev/null | awk '{print $2}' || echo '—')"
  ok "зависимости на месте"
fi

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
  #
  # The role is ASKED OF THE CONTAINER, not assumed. `-U lzt` against a cluster initialised with a
  # different POSTGRES_USER fails with `role "lzt" does not exist` — which, with stderr discarded,
  # is indistinguishable from "the database is missing". The running container knows its own
  # superuser; .env is the fallback, the literal is the last resort.
  PGUSER_EFF="$(docker compose exec -T postgres printenv POSTGRES_USER 2>/dev/null | tr -d '\r\n')"
  [[ -n "$PGUSER_EFF" ]] || PGUSER_EFF="${POSTGRES_USER:-$(grep -m1 '^POSTGRES_USER=' .env 2>/dev/null | cut -d= -f2-)}"
  PGUSER_EFF="${PGUSER_EFF:-lzt}"
  PG_ERR="$(mktemp)"
  # `-d postgres` is not optional: without it psql connects to a database named after the ROLE, and
  # `lzt` has no such database (compose creates lztflow), so the probe failed with
  # `database "lzt" does not exist` — which reads as "lzteventus is missing" and killed a run where
  # the database had in fact just been created.
  db_exists() {
    docker compose exec -T postgres psql -U "$PGUSER_EFF" -d postgres -tAc \
      "SELECT 1 FROM pg_database WHERE datname='lzteventus'" 2>"$PG_ERR" | grep -qx 1
  }
  # Missing means CREATE IT — that is the installer's job. `CREATE DATABASE` over psql rather than
  # the createdb binary: it works regardless of which default database the image gives the role,
  # and "already exists" is success, not an error.
  db_create() {
    docker compose exec -T postgres psql -U "$PGUSER_EFF" -d postgres \
      -c 'CREATE DATABASE lzteventus' >/dev/null 2>"$PG_ERR" && return 0
    grep -q 'already exists' "$PG_ERR" && return 0
    return 1
  }
  for _ in $(seq 1 15); do
    db_exists && break
    db_create && break
    sleep 2
  done
fi
# Both loops above can exhaust their retries and fall through. This line used to print regardless,
# so a Postgres that never came healthy — or a missing lzteventus database — was reported as up, and
# the real cause surfaced later as an opaque alembic error in phase 5.
if [[ $DRY_RUN == 0 ]]; then
  pg_state="$(docker inspect -f '{{.State.Health.Status}}' open-lzt-postgres-1 2>/dev/null || echo none)"
  [[ "$pg_state" == healthy ]] || die "postgres не поднялся (состояние: $pg_state) — docker compose logs postgres"
  if ! db_exists; then
    # One last attempt before giving up — the retry window may simply have been shorter than a
    # first-boot initdb on a slow disk.
    db_create && sleep 1
  fi
  if ! db_exists; then
    # Print what postgres actually said. A bare verdict sent an operator looking for a missing
    # database when the real answer was a role name, and the tool had already been told.
    if [[ -s "$PG_ERR" ]]; then
      warn "postgres ответил:"
      sed 's/^/      /' "$PG_ERR" >&2
    fi
    info "посмотреть список баз и ролей:"
    printf '      %sdocker compose exec -T postgres psql -U %s -d postgres -l%s\n' "$c_dim" "$PGUSER_EFF" "$c_reset"
    printf '      %sdocker compose exec -T postgres psql -U %s -d postgres -c "\\\\du"%s\n' "$c_dim" "$PGUSER_EFF" "$c_reset"
    rm -f "$PG_ERR"
    die "базы lzteventus нет (роль: $PGUSER_EFF) — миграции eventus пойдут в пустоту"
  fi
  rm -f "$PG_ERR"
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
  # The eventus engine builds a pylzt Client eagerly at boot and refuses an empty token list.
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

  # The world (seller roster, forum, lazily materialised lots) is what makes the mock browsable
  # without a single real account, so a stand wants it on. The library keeps it off by default:
  # the plain mock is stateless there.
  cat > deploy/env/testnet.env <<EOF
LZT_TESTNET_HOST=127.0.0.1
LZT_TESTNET_PORT=${TESTNET_PORT}
LZT_TESTNET_WORLD=1
EOF

  # A source backs its poll cadence off toward the max when polls turn up nothing, which is
  # right against the real marketplace and wrong against a mock: there is no rate limit to
  # respect, and a stand that has been idle polls every two minutes, so anything a demo or a
  # test does takes that long to be noticed. Only on testnet.
  eventus_cadence=""
  if [[ "${MARKET_MODE}" == "testnet" ]]; then
    eventus_cadence=$'LZT_MIN_CADENCE=3
LZT_DEFAULT_CADENCE=5
LZT_MAX_CADENCE=10'
  fi

  cat > deploy/env/eventus.env <<EOF
LZT_DATABASE_URL=${pg_sync}/lzteventus
LZT_REDIS_URL=${redis}/1
LZT_ADMIN_API_KEY=${EVENTUS_ADMIN_API_KEY}
LZT_TOKEN_ENC_KEY=${EVENTUS_TOKEN_ENC_KEY}
LZT_TOKENS=${eventus_tokens}
LZT_API_BASE_URL=${testnet_url}
LZT_HEALTH_HOST=127.0.0.1
LZT_HEALTH_PORT=${EVENTUS_PORT}
${eventus_cadence}
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
PANEL_BUILT=0
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
  PANEL_BUILT=1
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
  # Token through the environment, not argv: /proc/<pid>/cmdline is world-readable.
  if [[ -n "$_admins" ]]; then
    BOT_TOKEN="$_tok" bash scripts/bot-bootstrap.sh --admins "$_admins" \
      || warn "bot setup had issues — see output above"
  else
    warn "a bot token without admin ids answers everyone — bot NOT started (pass --bot-admins)"
  fi
fi
[[ -f deploy/env/bot.env ]] || info "telegram bot: off — enable later with 'sudo bash scripts/bot-bootstrap.sh --token <t> --admins <ids>'"

# ---- public access / TLS ------------------------------------------------------------------------
# A public CA cannot certify a bare IP (no domain), so the default here — nobody opted in or out —
# is a self-signed cert with the IP itself as subjectAltName. deploy/setup_tls.sh owns ALL nginx
# site config from here on (plain-HTTP-only counts as one of its modes too), so this is the single
# place that writes the site, whichever way TLS_MODE resolves.
phase "Public access & nginx"
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
    read -r -p "  No domain. Install a self-signed cert on this IP instead? [Y/n]: " _ss </dev/tty || _ss=""
    [[ "$_ss" =~ ^[Nn] ]] && TLS_MODE="none" || TLS_MODE="selfsigned"
  fi
elif [[ $DRY_RUN == 0 && -z "${DOMAIN:-}" && "${TLS_MODE:-none}" == "none" ]]; then
  # Non-interactive (--yes) and nobody said --tls none: a bare-IP install still ends up on HTTPS.
  TLS_MODE="selfsigned"
fi
if [[ $DRY_RUN == 0 ]]; then
  set_kv .env DOMAIN "${DOMAIN:-}"; set_kv .env TLS_MODE "${TLS_MODE:-none}"
  set_kv .env LETSENCRYPT_EMAIL "${LETSENCRYPT_EMAIL:-}"
fi
PANEL_OK=0
if [[ $DRY_RUN == 0 ]]; then
  if EVENTUS_PORT="${EVENTUS_PORT}" bash deploy/setup_tls.sh "${DOMAIN:-}" "${LETSENCRYPT_EMAIL:-}" "${TLS_MODE:-none}" "${FLOW_PORT}"; then
    PANEL_OK=1
  else
    warn "не удалось настроить nginx — панель не раздаётся (причина выше)"
  fi
else
  info "dry-run: skipping nginx/TLS setup"
fi

# ---- summary box --------------------------------------------------------------------------------
svc_line() { # name port
  # `is-active` exits non-zero for every state that is not "active" — including "activating",
  # where it still PRINTS the state. The `|| echo unknown` then appended a second line and the
  # box grew a stray "unknown" under the service. Take the printed value when there is one.
  local state; state=$(systemctl is-active "open-lzt-$1" 2>/dev/null | head -1)
  [[ -n "$state" ]] || state=unknown
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
PANEL_HOST="${DOMAIN:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
PANEL_SCHEME=https; [[ "${TLS_MODE:-none}" == "none" ]] && PANEL_SCHEME=http
# Only claim an address that answers. Printing "Panel: https://<ip>/" after nginx refused the
# config sent an operator to a refused connection with the installer still reporting success.
if (( PANEL_OK )) && curl -skS -o /dev/null --max-time 5 "$PANEL_SCHEME://127.0.0.1/" 2>/dev/null; then
  printf '%s│%s  %s%s:%s %s://%s/\n' \
    "$c_cyan" "$c_reset" "$c_green$c_bold" "$( (( PANEL_BUILT )) && echo "Панель" || echo "API" )" \
    "$c_reset" "$PANEL_SCHEME" "${PANEL_HOST:-this-host}"
  # Calling it "Панель" over a root that serves the API is the same lie as naming an address that
  # does not answer — the panel simply was not built, and it should be said here, not guessed.
  (( PANEL_BUILT )) || printf '%s│%s  %sпанель не собрана — по / отдаётся API (причина в фазе 4b)%s\n' \
    "$c_cyan" "$c_reset" "$c_yellow" "$c_reset"
  [[ "${TLS_MODE:-none}" == "selfsigned" ]] \
    && printf '%s│%s  %sсертификат самоподписанный — браузер предупредит один раз%s\n' \
         "$c_cyan" "$c_reset" "$c_dim" "$c_reset"
elif (( DRY_RUN )); then
  printf '%s│%s  %sПанель:%s %s://%s/\n' \
    "$c_cyan" "$c_reset" "$c_green$c_bold" "$c_reset" "$PANEL_SCHEME" "${PANEL_HOST:-this-host}"
else
  printf '%s│%s  %sПанель не поднялась%s — API работает на 127.0.0.1:%s\n' \
    "$c_cyan" "$c_reset" "$c_red$c_bold" "$c_reset" "${FLOW_PORT}"
  # The real call exports EVENTUS_PORT and passes the domain/email; a repair command missing them
  # renders a different config than the one that just failed.
  printf '%s│%s  %sчинить: EVENTUS_PORT=%s bash %s/deploy/setup_tls.sh "%s" "%s" %s %s%s\n' \
    "$c_cyan" "$c_reset" "$c_dim" "${EVENTUS_PORT}" "$INSTALL_DIR" "${DOMAIN:-}" \
    "${LETSENCRYPT_EMAIL:-}" "${TLS_MODE:-none}" "${FLOW_PORT}" "$c_reset"
fi
printf '%s├%s┤%s\n' "$c_cyan" "$_rule" "$c_reset"
# The bot's @name comes from getMe, written into bot.env by scripts/bot-bootstrap.sh — the operator
# typed a token, so this is the one place they can learn which bot it actually is.
if [[ -f deploy/env/bot.env ]]; then
  BOT_NAME="$(grep -m1 '^LZT_FLOW_BOT_USERNAME=' deploy/env/bot.env 2>/dev/null | cut -d= -f2-)"
  if [[ -n "$BOT_NAME" ]]; then
    printf '%s│%s  %sБот:%s @%s · https://t.me/%s\n' \
      "$c_cyan" "$c_reset" "$c_green$c_bold" "$c_reset" "$BOT_NAME" "$BOT_NAME"
  else
    printf '%s│%s  %sБот:%s запущен, имя получить не удалось (getMe не ответил)\n' \
      "$c_cyan" "$c_reset" "$c_yellow" "$c_reset"
  fi
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
# Ports come from what the install actually used; the literal version printed a tunnel to the
# defaults on any stand that moved a port, and never forwarded MCP at all.
cmd "ssh -N -L ${FLOW_PORT}:127.0.0.1:${FLOW_PORT} -L ${EVENTUS_PORT}:127.0.0.1:${EVENTUS_PORT} -L ${TESTNET_PORT}:127.0.0.1:${TESTNET_PORT} -L ${MCP_PORT}:127.0.0.1:${MCP_PORT} root@<server>"

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
note "monorepo   https://github.com/open-lzt/open-lzt        (README · docs/AUTOUPDATE.md)"
note "projects   /pylzt /lzt-testnet /lzt-eventus /auto-lzt /lzt-mcp under github.com/open-lzt"
printf '\n'
