#!/usr/bin/env bash
# Put a ready-made flow onto a running open-lzt stand, in one command:
#
#   wget -qO- https://raw.githubusercontent.com/open-lzt/open-lzt/main/install-flow.sh | sudo bash
#
# It picks a module from the catalogue, asks for that module's parameters, creates the flow and
# offers to run it. It NEVER installs the stand itself — if there is no stand it prints install.sh
# and stops, because silently installing a whole platform is not what "install a flow" means.
#
# Non-interactive is a first-class mode, not a fallback:
#   bash install-flow.sh --module steam-autobuy --param max_price=10 --param count=1
# Anything passed with --param is never asked for. With no terminal at all, every unanswered
# parameter takes its declared default and the script still finishes instead of blocking.
set -euo pipefail

OPEN_LZT_REPO="${OPEN_LZT_REPO:-https://github.com/open-lzt/open-lzt}"
OPEN_LZT_DIR="${OPEN_LZT_DIR:-/opt/open-lzt}"

c_reset=$'\033[0m'; c_cyan=$'\033[1;36m'; c_green=$'\033[1;32m'; c_red=$'\033[1;31m'
c_dim=$'\033[2m'; c_bold=$'\033[1m'; c_yellow=$'\033[1;33m'

say()  { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
step() { printf '\n%s▸%s %s%s%s\n' "$c_cyan" "$c_reset" "$c_bold" "$*" "$c_reset"; }
ok()   { printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '  %s✗%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

MODULE=""
declare -A CLI_PARAMS=()
AUTO_RUN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module) MODULE="${2:-}"; shift 2 ;;
    --param)
      [[ "${2:-}" == *=* ]] || die "--param expects key=value, got '${2:-}'"
      CLI_PARAMS["${2%%=*}"]="${2#*=}"; shift 2 ;;
    --run)    AUTO_RUN=1; shift ;;
    --no-run) AUTO_RUN=0; shift ;;
    --dir)    OPEN_LZT_DIR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# ── the stand must already exist ───────────────────────────────────────────────
# Checked BEFORE any clone: a machine with no stand should get one clear message, not a repo it
# never asked for followed by an error.
ENV_FILE="$OPEN_LZT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  printf '\n%s✗%s открытого стенда в %s нет — сначала поставьте его:\n\n' \
    "$c_red" "$c_reset" "$OPEN_LZT_DIR"
  printf '    wget -qO- %s/raw/main/install.sh | sudo bash\n\n' "$OPEN_LZT_REPO"
  exit 1
fi
[[ $EUID -eq 0 ]] || die "нужен root, чтобы прочитать $ENV_FILE: … | sudo bash"

# Same helper scripts/bot-bootstrap.sh uses — one way to read a key out of .env.
get_kv() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- || true; }

FKEY="$(get_kv "$ENV_FILE" FLOW_API_KEY)"
FPORT="$(get_kv "$ENV_FILE" FLOW_PORT)"; FPORT="${FPORT:-8000}"
FLOW="http://127.0.0.1:${FPORT}"

step "Стенд"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$FLOW/catalog/list" -H "X-API-Key: $FKEY" || true)
[[ "$HTTP_CODE" == "200" ]] || die "flow-api на $FLOW не отвечает (HTTP $HTTP_CODE) — systemctl status open-lzt-flow-api"
ok "flow-api отвечает на $FLOW"

# ── the catalogue, local checkout first ────────────────────────────────────────
MODULES_DIR="$OPEN_LZT_DIR/lzt-flows/modules"
if [[ ! -d "$MODULES_DIR" ]]; then
  say "каталога модулей нет — доскачиваем"
  command -v git >/dev/null || die "нужен git: apt-get install -y git"
  git -C "$OPEN_LZT_DIR" submodule update --init --recursive >/dev/null 2>&1 \
    || die "не удалось получить lzt-flows — проверьте $OPEN_LZT_DIR"
fi
[[ -d "$MODULES_DIR" ]] || die "нет $MODULES_DIR"

# The first line of module.yaml's `description:` block, in ONE awk process. Not a `sed | grep | head`
# pipeline: `head` exits early, the upstream stage takes SIGPIPE, and `set -o pipefail` would then
# kill this script over a cosmetic menu caption.
first_description() {
  awk '/^description:/ {inblock = 1; next}
       inblock && /^[a-z_]+:/ {exit}
       inblock && NF {sub(/^[ \t]+/, ""); print; exit}' "$1" 2>/dev/null
}

NAMES=(); DESCS=()
for dir in "$MODULES_DIR"/*/; do
  [[ -f "$dir/flow.json" && -f "$dir/module.yaml" ]] || continue
  NAMES+=("$(basename "$dir")")
  desc=$(first_description "$dir/module.yaml" || true)
  DESCS+=("${desc:-—}")
done
[[ ${#NAMES[@]} -gt 0 ]] || die "в $MODULES_DIR нет ни одного flow-модуля"

# ── pick a module ──────────────────────────────────────────────────────────────
# Prompts read /dev/tty, never stdin: the script itself arrives on stdin when it is piped from wget.
# The probe OPENS /dev/tty rather than testing `-r`, because under a service manager or a bare pipe
# the device node exists and passes `-r` while every open still fails with ENXIO — testing `-r` here
# means the no-terminal path never runs and a parameter without a default re-prompts forever.
if { : < /dev/tty; } 2>/dev/null; then INTERACTIVE=1; else INTERACTIVE=0; fi

tty_read() {
  local __var="$1" __prompt="$2" __silent="${3:-}" __line="" __rc=0
  if [[ $INTERACTIVE == 0 ]]; then printf -v "$__var" '%s' ''; return 1; fi
  # read's status is propagated so a Ctrl-D breaks the caller's re-prompt loop instead of feeding
  # it an endless stream of empty answers.
  if [[ -n "$__silent" ]]; then
    read -rs -p "$__prompt" __line < /dev/tty || __rc=$?; printf '\n'
  else
    read -r -p "$__prompt" __line < /dev/tty || __rc=$?
  fi
  printf -v "$__var" '%s' "$__line"
  return "$__rc"
}

if [[ -z "$MODULE" ]]; then
  step "Модули"
  for i in "${!NAMES[@]}"; do
    printf '  %s%2d%s  %-20s %s%s%s\n' \
      "$c_bold" "$((i + 1))" "$c_reset" "${NAMES[$i]}" "$c_dim" "${DESCS[$i]}" "$c_reset"
  done
  if tty_read choice $'\n  номер модуля: '; then
    [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#NAMES[@]} )) \
      || die "нужен номер от 1 до ${#NAMES[@]}"
    MODULE="${NAMES[$((choice - 1))]}"
  else
    die "нет терминала для выбора — передайте --module <имя>"
  fi
fi

MODULE_DIR="$MODULES_DIR/$MODULE"
[[ -f "$MODULE_DIR/flow.json" ]] || die "модуля '$MODULE' нет; доступны: ${NAMES[*]}"
ok "модуль: $MODULE"

# ── parameters ─────────────────────────────────────────────────────────────────
# The param surface is flow.json's own `params` array, so the script never carries a second copy of
# a module's contract. python3 reads it (the stand already depends on python3).
#
# Fields are joined with US (0x1f), NOT a tab. A tab is IFS whitespace, and bash collapses runs of
# IFS whitespace into one delimiter — so a param with no `options` would silently shift `minimum`
# and `maximum` one column left, and `count` would reject its own default with "minimum 50".
SEP=$'\x1f'
PARAM_ROWS=$(python3 - "$MODULE_DIR/flow.json" <<'PY'
import json, sys
spec = json.load(open(sys.argv[1], encoding="utf-8"))
for p in spec.get("params", []):
    opts = "|".join(f"{o['value']}={o['label']}" for o in (p.get("options") or []))
    default = p.get("default")
    default = "" if default is None else json.dumps(default, ensure_ascii=False).strip('"')
    print("\x1f".join([
        p["key"], p.get("label", p["key"]), p.get("control", "text"),
        "1" if p.get("required", True) else "0", default, opts,
        "" if p.get("minimum") is None else str(p["minimum"]),
        "" if p.get("maximum") is None else str(p["maximum"]),
    ]))
PY
)

declare -A VALUES=()
if [[ -n "$PARAM_ROWS" ]]; then
  step "Параметры"
  while IFS="$SEP" read -r key label control required default opts minimum maximum; do
    [[ -n "$key" ]] || continue

    # A value given on the command line is never asked for again.
    if [[ -n "${CLI_PARAMS[$key]+x}" ]]; then
      VALUES["$key"]="${CLI_PARAMS[$key]}"
      ok "$label = ${CLI_PARAMS[$key]} ${c_dim}(--param)${c_reset}"
      continue
    fi

    if [[ $INTERACTIVE == 0 ]]; then
      if [[ -n "$default" ]]; then
        VALUES["$key"]="$default"
        say "$label = $default (по умолчанию)"
      elif [[ "$required" == "1" ]]; then
        die "нет терминала и нет значения для обязательного '$key' — передайте --param $key=<значение>"
      fi
      continue
    fi

    case "$control" in
      select|radio)
        printf '  %s%s%s\n' "$c_bold" "$label" "$c_reset"
        mapfile -t choices < <(printf '%s' "$opts" | tr '|' '\n')
        for i in "${!choices[@]}"; do
          printf '     %2d) %s\n' "$((i + 1))" "${choices[$i]#*=}"
        done
        while true; do
          tty_read reply "     номер${default:+ [$default]}: " || break
          [[ -z "$reply" && -n "$default" ]] && { VALUES["$key"]="$default"; break; }
          if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#choices[@]} )); then
            VALUES["$key"]="${choices[$((reply - 1))]%%=*}"; break
          fi
          warn "нужен номер от 1 до ${#choices[@]}"
        done ;;
      toggle)
        while true; do
          tty_read reply "  $label (y/n)${default:+ [$default]}: " || break
          [[ -z "$reply" && -n "$default" ]] && { VALUES["$key"]="$default"; break; }
          case "${reply,,}" in
            y|yes|true|1)  VALUES["$key"]=true;  break ;;
            n|no|false|0)  VALUES["$key"]=false; break ;;
            *) warn "ответьте y или n" ;;
          esac
        done ;;
      number|slider|delay)
        while true; do
          tty_read reply "  $label${default:+ [$default]}: " || break
          [[ -z "$reply" && -n "$default" ]] && { VALUES["$key"]="$default"; break; }
          if [[ ! "$reply" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then warn "нужно число"; continue; fi
          if [[ -n "$minimum" ]] && awk -v a="$reply" -v b="$minimum" 'BEGIN{exit !(a<b)}'; then
            warn "минимум $minimum"; continue
          fi
          if [[ -n "$maximum" ]] && awk -v a="$reply" -v b="$maximum" 'BEGIN{exit !(a>b)}'; then
            warn "максимум $maximum"; continue
          fi
          VALUES["$key"]="$reply"; break
        done ;;
      *)
        # A token is a secret even when the control is a plain text box.
        silent=""; [[ "$key" == *token* || "$key" == *secret* ]] && silent=1
        tty_read reply "  $label${default:+ [$default]}: " "$silent" || true
        [[ -z "$reply" && -n "$default" ]] && reply="$default"
        [[ -n "$reply" ]] && VALUES["$key"]="$reply" ;;
    esac

    # Every branch above can also exit on Ctrl-D, so the required/default rule is settled once, here,
    # rather than four times inside the loops.
    if [[ -z "${VALUES[$key]+x}" ]]; then
      if [[ -n "$default" ]]; then
        VALUES["$key"]="$default"
      elif [[ "$required" == "1" ]]; then
        die "'$key' обязателен — передайте --param $key=<значение>"
      fi
    fi
  done <<< "$PARAM_ROWS"
fi

# ── create ────────────────────────────────────────────────────────────────────
step "Создаём флоу"
PARAMS_JSON=$(
  for k in "${!VALUES[@]}"; do printf '%s\t%s\n' "$k" "${VALUES[$k]}"; done \
  | python3 -c '
import json, sys
out = {}
for line in sys.stdin:
    if not line.strip():
        continue
    k, _, v = line.rstrip("\n").partition("\t")
    if v in ("true", "false"):
        out[k] = v == "true"
    else:
        try:
            out[k] = int(v)
        except ValueError:
            try:
                out[k] = float(v)
            except ValueError:
                out[k] = v
print(json.dumps(out, ensure_ascii=False))
'
)

RESP=$(curl -s -w '\n%{http_code}' -X POST "$FLOW/flows/create" \
  -H "X-API-Key: $FKEY" -H 'Content-Type: application/json' \
  --data-binary @"$MODULE_DIR/flow.json")
CODE=$(printf '%s' "$RESP" | tail -1)
BODY=$(printf '%s' "$RESP" | sed '$d')
[[ "$CODE" == "201" ]] || die "flows/create вернул $CODE: $BODY"
FLOW_ID=$(printf '%s' "$BODY" | python3 -c 'import sys,json;print(json.load(sys.stdin)["flow_id"])')
ok "флоу создан: $FLOW_ID"

curl -s -o /dev/null -X POST "$FLOW/flows/$FLOW_ID/compile" \
  -H "X-API-Key: $FKEY" -H 'Content-Type: application/json' -d '{}' || true
ok "граф скомпилирован"

# ── run ───────────────────────────────────────────────────────────────────────
if [[ -z "$AUTO_RUN" ]]; then
  if [[ $INTERACTIVE == 1 ]]; then
    tty_read reply $'\n  запустить сейчас? (y/n) [n]: ' || reply=""
    case "${reply,,}" in y|yes) AUTO_RUN=1 ;; *) AUTO_RUN=0 ;; esac
  else
    AUTO_RUN=0
  fi
fi

RUN_CMD="curl -s -X POST $FLOW/runs/create -H 'X-API-Key: <ключ из $ENV_FILE>' \\
    -H 'Content-Type: application/json' \\
    -d '{\"flow_id\":\"$FLOW_ID\",\"run_key\":\"$MODULE-1\",\"params\":$PARAMS_JSON}'"

if [[ "$AUTO_RUN" == "1" ]]; then
  step "Запуск"
  RUN_BODY=$(curl -s -X POST "$FLOW/runs/create" -H "X-API-Key: $FKEY" \
    -H 'Content-Type: application/json' \
    -d "{\"flow_id\":\"$FLOW_ID\",\"run_key\":\"$MODULE-$(date +%s)\",\"params\":$PARAMS_JSON}")
  RUN_ID=$(printf '%s' "$RUN_BODY" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin).get("run_id",""))' 2>/dev/null || true)
  [[ -n "$RUN_ID" ]] || die "runs/create: $RUN_BODY"
  ok "запущен: $RUN_ID"
  say "статус: curl -s $FLOW/runs/$RUN_ID/get -H \"X-API-Key: \$(grep ^FLOW_API_KEY= $ENV_FILE | cut -d= -f2)\""
else
  step "Готово — флоу создан, но не запущен"
  printf '%s%s%s\n' "$c_dim" "$RUN_CMD" "$c_reset"
fi
