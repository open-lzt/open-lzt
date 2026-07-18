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
  cat >"$BOT_ENV" <<EOF
LZT_FLOW_BOT_ENABLED=1
LZT_FLOW_BOT_TOKEN=${CUR_TOKEN}
LZT_FLOW_BOT_ADMIN_IDS=${CUR_ADMINS}
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
run "systemctl enable --now open-lzt-bot.service"

if [[ $DRY_RUN == 0 ]]; then
  sleep 2
  if systemctl is-active --quiet open-lzt-bot.service; then
    ok "bot is running — send /start to it in Telegram"
  else
    die "bot failed to start: journalctl -u open-lzt-bot -n 50"
  fi
fi
