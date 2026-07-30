#!/usr/bin/env bash
# One command to get a bot answering /start:
#
#   sudo bash scripts/bot-bootstrap.sh --token 123:ABC --admins 111,222
#
# Re-running it is safe and is the supported way to change the admin list. It does NOT duplicate the
# unit, rotate a token you did not pass, or wipe the admins you already have (R-13): every write
# goes through set_kv, exactly as install.sh does, so absent flags mean "leave it alone" rather than
# "reset it". That matters because the obvious failure — re-running the installer and silently
# emptying the admin list — turns the bot into one that answers everybody.
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ENV_FILE="$INSTALL_DIR/.env"
BOT_ENV="$INSTALL_DIR/deploy/env/bot.env"
UNIT_SRC="$INSTALL_DIR/deploy/systemd/open-lzt-bot.service"
UNIT_DST="/etc/systemd/system/open-lzt-bot.service"

TOKEN=""
ADMINS=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)   TOKEN="${2:-}"; shift 2 ;;
    --admins)  ADMINS="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\033[36m›\033[0m %s\n' "$1"; }
ok()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }
run() { if [[ $DRY_RUN == 1 ]]; then printf '   [dry-run] %s\n' "$*"; else eval "$@"; fi; }

# Same helper install.sh:31 uses: replace in place if present, append if not. Never truncate.
set_kv() {
  local f="$1" k="$2" v="$3"
  [[ $DRY_RUN == 1 ]] && { printf '   [dry-run] would set %s in %s\n' "$k" "$f"; return; }
  if grep -q "^${k}=" "$f"; then sed -i "s|^${k}=.*|${k}=${v}|" "$f"; else echo "${k}=${v}" >>"$f"; fi
}

get_kv() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- || true; }

[[ -f "$ENV_FILE" ]] || die ".env not found — run install.sh first"

if [[ -n "$ADMINS" && ! "$ADMINS" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
  die "--admins must be numeric Telegram ids, comma-separated (e.g. 111,222)"
fi

# A token passed as --token sits in argv, and /proc/<pid>/cmdline is world-readable — any local
# user can read it for the process lifetime. The environment is not (/proc/<pid>/environ is 0400),
# so callers hand it over that way; --token stays for interactive use.
TOKEN="${TOKEN:-${BOT_TOKEN:-}}"
[[ -n "$TOKEN" ]]  && { set_kv "$ENV_FILE" BOT_TOKEN "$TOKEN"; ok "token set"; }
[[ -n "$ADMINS" ]] && { set_kv "$ENV_FILE" BOT_ADMIN_IDS "$ADMINS"; ok "admins set: $ADMINS"; }
set_kv "$ENV_FILE" BOT_ENABLED 1
run "chmod 600 '$ENV_FILE'"

CUR_TOKEN="$(get_kv "$ENV_FILE" BOT_TOKEN)"
CUR_ADMINS="$(get_kv "$ENV_FILE" BOT_ADMIN_IDS)"
if [[ $DRY_RUN == 0 ]]; then
  [[ -n "$CUR_TOKEN" ]]  || die "no BOT_TOKEN — pass --token 123:ABC"
  # A bot with a token and no admins answers everyone. Refuse to start one.
  [[ -n "$CUR_ADMINS" ]] || die "no BOT_ADMIN_IDS — pass --admins 111,222"
fi

FLOW_API_KEY="$(get_kv "$ENV_FILE" FLOW_API_KEY)"
FLOW_PORT="$(get_kv "$ENV_FILE" FLOW_PORT)"; FLOW_PORT="${FLOW_PORT:-8000}"

say "rendering $BOT_ENV"
run "install -d -m700 '$INSTALL_DIR/deploy/env'"
if [[ $DRY_RUN == 0 ]]; then
  # pydantic-settings JSON-decodes any field whose type is complex, and admin_ids is a frozenset.
  # A bare `1744691089` therefore arrives as an int and fails with `Input should be a valid
  # frozenset` — so ONE admin crash-looped the bot while a comma-separated pair would have parsed.
  # Emit a JSON array; the value is validated as digits-and-commas above, so wrapping it suffices.
  ADMINS_JSON="[$(printf '%s' "$CUR_ADMINS" | tr -d ' ')]"
  cat >"$BOT_ENV" <<EOF
LZT_FLOW_BOT_ENABLED=1
LZT_FLOW_BOT_TOKEN=${CUR_TOKEN}
LZT_FLOW_BOT_ADMIN_IDS=${ADMINS_JSON}
LZT_FLOW_BOT_API_BASE_URL=http://127.0.0.1:${FLOW_PORT}
LZT_FLOW_BOT_API_KEY=${FLOW_API_KEY}
EOF
  chmod 600 "$BOT_ENV"
fi
ok "bot env rendered"

if [[ $EUID -ne 0 && $DRY_RUN == 0 ]]; then
  say "not root — skipping the systemd unit. Re-run with sudo to install it."
  exit 0
fi

# install -C replaces only when the content differs, so a re-run is a no-op rather than a restart.
say "installing unit"
run "install -C -m644 '$UNIT_SRC' '$UNIT_DST'"
run "systemctl daemon-reload"
run "systemctl enable open-lzt-bot.service"
# `enable --now` only STARTS an inactive unit — a bot already running keeps the previous bot.env,
# so a re-run that changed the token or the admins would appear to succeed and change nothing.
run "systemctl restart open-lzt-bot.service"

if [[ $DRY_RUN == 0 ]]; then
  # `is-active` two seconds in is not proof the bot started: this unit restarts on failure, and the
  # crash comes ~7s in (interpreter boot, then settings validation), so the early probe caught the
  # first, doomed attempt and reported success while the service crash-looped. Watch the restart
  # counter instead of a single instant.
  restarts_before="$(systemctl show -p NRestarts --value open-lzt-bot.service 2>/dev/null || echo 0)"
  sleep 12
  restarts_after="$(systemctl show -p NRestarts --value open-lzt-bot.service 2>/dev/null || echo 0)"
  if systemctl is-active --quiet open-lzt-bot.service && [[ "$restarts_after" == "$restarts_before" ]]; then
    # The operator typed a token, not a name — so ask Telegram which bot it belongs to instead of
    # sending them to look it up. getMe doubles as the only real proof the token is valid.
    BOT_USER="$(curl -fsS --max-time 8 "https://api.telegram.org/bot${CUR_TOKEN}/getMe" 2>/dev/null \
      | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin)
    print(d["result"]["username"] if d.get("ok") else "")
except Exception:
    print("")' 2>/dev/null || true)"
    if [[ -n "$BOT_USER" ]]; then
      # Kept in bot.env so the installer's final block can name it without holding the token.
      grep -q '^LZT_FLOW_BOT_USERNAME=' "$BOT_ENV" 2>/dev/null \
        || printf 'LZT_FLOW_BOT_USERNAME=%s\n' "$BOT_USER" >>"$BOT_ENV"
      ok "bot is running — @${BOT_USER} · https://t.me/${BOT_USER}"
    else
      ok "bot is running — send /start to it in Telegram"
      warn "имя бота получить не удалось (getMe не ответил) — проверьте токен и сеть"
    fi
  else
    warn "бот не удержался (перезапусков: ${restarts_before} → ${restarts_after})"
    journalctl -u open-lzt-bot -n 20 --no-pager 2>/dev/null | sed 's/^/      /' >&2 || true
    die "bot failed to start: journalctl -u open-lzt-bot -n 50"
  fi
fi
