#!/usr/bin/env bash
# open-lzt end-to-end demo. One command, every project, real logs.
#
#   wget -qO- https://raw.githubusercontent.com/open-lzt/open-lzt/main/demo.sh | sudo bash
#
# or, from a clone:
#   bash demo.sh                 # testnet — nothing touches the real market
#   bash demo.sh --mode prod     # REAL market, REAL money (asks first)
#   bash demo.sh --skip-install  # stand is already up, go straight to the scenes
#
# The demo installs the stack, health-checks it, then walks one scene per project,
# printing the request it sends and the response it gets back — no summaries, the
# actual bytes.
set -uo pipefail

# ---- bootstrap ----------------------------------------------------------------------------------
# Piped from the network there is no repo to run against: fetch one, then hand over to the copy on
# disk. `exec` and not a function call, so everything below runs with a real ${BASH_SOURCE[0]} and
# a working directory — the rest of the script assumes both.
OPEN_LZT_REPO="${OPEN_LZT_REPO:-https://github.com/open-lzt/open-lzt}"
OPEN_LZT_DIR="${OPEN_LZT_DIR:-/opt/open-lzt}"
_self="${BASH_SOURCE[0]:-}"
if [[ -z "$_self" || ! -f "$_self" || ! -f "$(dirname "$_self")/install.sh" ]]; then
  printf '\033[1;36m▸ bootstrap\033[0m — качаем open-lzt в %s\n' "$OPEN_LZT_DIR"
  [[ $EUID -eq 0 ]] || { printf '  нужен root: wget -qO- .../demo.sh | sudo bash\n'; exit 1; }
  command -v git >/dev/null || { apt-get update -qq && apt-get install -y -qq git ca-certificates; }
  if [[ -d "$OPEN_LZT_DIR/.git" ]]; then
    git -C "$OPEN_LZT_DIR" pull --ff-only --recurse-submodules
  else
    git clone --recurse-submodules --depth 1 "$OPEN_LZT_REPO" "$OPEN_LZT_DIR"
  fi
  exec bash "$OPEN_LZT_DIR/demo.sh" "$@"
fi

MODE=testnet
SKIP_INSTALL=0
ASSUME_YES=0
BUY_COUNT=3
BUY_MAX_PRICE=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-testnet}"; shift 2 ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --count) BUY_COUNT="${2:-3}"; shift 2 ;;
    --max-price) BUY_MAX_PRICE="${2:-10}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) printf 'unknown flag: %s\n' "$1"; exit 2 ;;
  esac
done
[[ "$MODE" == testnet || "$MODE" == prod ]] || { printf 'mode must be testnet or prod\n'; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

c_reset=$'\033[0m'; c_cyan=$'\033[1;36m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'
c_red=$'\033[1;31m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'; c_mag=$'\033[1;35m'; c_blue=$'\033[1;34m'
_rule="──────────────────────────────────────────────────────────────────────"

scene()  { printf '\n%s╭%s╮%s\n' "$c_mag" "$_rule" "$c_reset"
           printf '%s│%s %s%-69s%s%s│%s\n' "$c_mag" "$c_reset" "$c_bold" "$*" "$c_reset" "$c_mag" "$c_reset"
           printf '%s╰%s╯%s\n' "$c_mag" "$_rule" "$c_reset"; }
step()   { printf '\n%s▸%s %s%s%s\n' "$c_cyan" "$c_reset" "$c_bold" "$*" "$c_reset"; }
say()    { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
ok()     { printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
bad()    { printf '  %s✗%s %s\n' "$c_red" "$c_reset" "$*"; }
warn()   { printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }

FAILURES=0
fail() { bad "$*"; FAILURES=$((FAILURES + 1)); }

# Pretty-print JSON without depending on jq (not installed by install.sh).
pp() { python3 -c 'import json,sys
raw = sys.stdin.read().strip()
if not raw:
    print("   (empty response)"); sys.exit()
try:
    parsed = json.loads(raw)
except json.JSONDecodeError:
    print("\n".join("   " + line for line in raw.splitlines()[:20])); sys.exit()
text = json.dumps(parsed, indent=2, ensure_ascii=False)
lines = text.splitlines()
for line in lines[:60]:
    print("   " + line)
if len(lines) > 60:
    print(f"   … +{len(lines) - 60} more lines")'; }

# req METHOD URL [body] [header...] — prints what it sends, then what came back.
req() {
  local method="$1" url="$2" body="${3:-}"; shift 3 2>/dev/null || shift 2
  printf '  %s→ %s %s%s\n' "$c_blue" "$method" "$url" "$c_reset"
  [[ -n "$body" ]] && printf '%s\n' "$body" | pp
  printf '  %s← response%s\n' "$c_green" "$c_reset"
  local out
  if [[ -n "$body" ]]; then
    out=$(curl -sS -X "$method" "$url" -H 'Content-Type: application/json' "$@" -d "$body" 2>&1)
  else
    out=$(curl -sS -X "$method" "$url" "$@" 2>&1)
  fi
  printf '%s' "$out" | pp
  LAST_RESPONSE="$out"
}

# jget PATH — pull one field out of $LAST_RESPONSE. Dotted path ("data.subscription_id") because
# eventus wraps every payload in a DataResponse envelope while flow returns the object flat.
jget() { printf '%s' "$LAST_RESPONSE" | python3 -c 'import json,sys
try:
    node = json.load(sys.stdin)
    for part in sys.argv[1].split("."):
        node = node[part]
    print(node)
except Exception:
    print("")' "$1"; }

# ───────────────────────────────────────────────────────────────────────────────
printf '\n%s╔%s╗%s\n' "$c_cyan" "$_rule" "$c_reset"
printf '%s║%s  %sopen-lzt · сквозное демо%s%*s%s║%s\n' "$c_cyan" "$c_reset" "$c_bold$c_green" "$c_reset" 44 "" "$c_cyan" "$c_reset"
printf '%s╚%s╝%s\n' "$c_cyan" "$_rule" "$c_reset"
say "режим: $MODE · покупок: $BUY_COUNT · потолок цены: $BUY_MAX_PRICE"

if [[ "$MODE" == prod ]]; then
  printf '\n%s╭%s╮%s\n' "$c_red" "$_rule" "$c_reset"
  printf '%s│%s %sРЕЖИМ PROD — НАСТОЯЩИЙ МАРКЕТ, НАСТОЯЩИЕ ДЕНЬГИ%s\n' "$c_red" "$c_reset" "$c_bold$c_red" "$c_reset"
  printf '%s│%s Флоу купит до %s аккаунтов по цене до %s ₽ каждый.\n' "$c_red" "$c_reset" "$BUY_COUNT" "$BUY_MAX_PRICE"
  printf '%s│%s Максимальная трата: %s ₽. Отменить покупку нельзя.\n' "$c_red" "$c_reset" "$((BUY_COUNT * BUY_MAX_PRICE))"
  printf '%s╰%s╯%s\n' "$c_red" "$_rule" "$c_reset"
  if [[ $ASSUME_YES == 0 ]]; then
    # `-e /dev/tty` alone is true on every box, attended or not; without also checking that
    # *our own* stdin is a terminal, an unattended run (cron, CI, systemd) would block forever
    # on the read instead of failing fast — same class of bug the installer had. Money is on
    # the line here, so the safe default when we can't ask is to refuse, not proceed.
    if [[ -t 0 && -e /dev/tty ]]; then
      read -r -p "  Напиши БУДУ ПОКУПАТЬ чтобы продолжить: " confirm </dev/tty || confirm=""
    else
      bad "не интерактивный запуск — нет тти для подтверждения (передай --yes для авто-подтверждения)"
      exit 1
    fi
    [[ "$confirm" == "БУДУ ПОКУПАТЬ" ]] || { bad "не подтверждено — выходим"; exit 1; }
  fi
fi

# ── 1. установка ───────────────────────────────────────────────────────────────
if [[ $SKIP_INSTALL == 0 ]]; then
  scene "1/8  Установка — весь стенд одной командой"
  say "install.sh ставит docker, uv, Postgres, Redis, синкает КАЖДЫЙ проект,"
  say "накатывает обе цепочки миграций и поднимает пять systemd-сервисов."
  say "Ниже — его собственный вывод, ничего не спрятано."
  printf '\n'
  # The flag, not the environment variable: `--mode prod` must reach the installer as an explicit
  # request, and a flag cannot be quietly overwritten by whatever .env already said.
  bash install.sh --yes --market-mode "$MODE" || fail "install.sh вернул ошибку"
else
  scene "1/8  Установка — пропущена (--skip-install)"
fi

set -a; [[ -f .env ]] && . ./.env; set +a
TESTNET="http://127.0.0.1:${TESTNET_PORT:-8765}"
EVENTUS="http://127.0.0.1:${EVENTUS_PORT:-27543}"
FLOW="http://127.0.0.1:${FLOW_PORT:-8000}"
FKEY="${FLOW_API_KEY:-}"
EKEY="${EVENTUS_ADMIN_API_KEY:-}"

# Each project has its own uv-managed venv — the system python3 has none of them importable.
PY_FLOW="$ROOT/projects/flow/.venv/bin/python"
PY_EVENTUS_SDK="$ROOT/projects/eventus-sdk/.venv/bin/python"
PY_MCP="$ROOT/projects/mcp/.venv/bin/python"

# ── 2. health ──────────────────────────────────────────────────────────────────
scene "2/8  Health-check — живы ли все пять сервисов"
bash scripts/healthcheck.sh || fail "health-check не прошёл"

# ── 3. testnet ─────────────────────────────────────────────────────────────────
scene "3/8  testnet — мок-маркет, в который смотрит весь стенд"
step "Кто там живой"
req GET "$TESTNET/testnet/health"
step "Сброс мира — тесты должны стартовать с чистого листа"
req POST "$TESTNET/testnet/reset" '{}'
step "Мир мока — сгенерированные лоты, их можно листать без единого реального аккаунта"
req GET "$TESTNET/testnet/world/lots?limit=3"
case "$LAST_RESPONSE" in
  *AuthFailed*|*NotFound*|"") fail "мок не отдал мир" ;;
  *) ok "мок сгенерировал каталог сам" ;;
esac
say "Каталог маркета мок отдаёт по тем же путям, что и настоящий API — через SDK, следующая сцена."

# ── 4. pylzt ───────────────────────────────────────────────────────────────────
scene "4/8  pylzt — типизированный SDK, тот же вызов из питона"
say "Тот же каталог, но через SDK: модели, а не словари."
"$PY_FLOW" - <<PYLZT || fail "pylzt сценарий упал"
import asyncio, os
from pylzt import Client
from pylzt.config import ClientConfig

BASE = "${TESTNET}"

async def main() -> None:
    cfg = ClientConfig(base_url=BASE, forum_base_url=BASE)
    async with Client(["testnet-fake-token"], config=cfg) as client:
        print("   пул токенов :", type(client._token_pool).__name__)
        page = await client.market.category_steam(pmax=${BUY_MAX_PRICE})
        print("   тип ответа  :", type(page).__name__)
        print("   всего лотов :", page.totalItems)
        for item in page.items[:3]:
            print(f"   лот {item.item_id:>8}  {item.price:>5} ₽  {item.title[:44]}")
            print(f"       поле price имеет тип {type(item.price).__name__}, не str из json")

asyncio.run(main())
PYLZT

# ── 5. eventus ─────────────────────────────────────────────────────────────────
scene "5/8  eventus — поллинг превращается в события с курсором"
step "Какие типы событий движок вообще знает"
req GET "$EVENTUS/event-types" "" -H "Authorization: Bearer $EKEY"
step "Подписка на новые лоты — транспорт polling, свой курсор"
req POST "$EVENTUS/subscriptions/create" \
  '{"transport":"polling","endpoint":"demo-poller","event_types":["new_lot"],"backfill":true}' \
  -H "Authorization: Bearer $EKEY"
SUB_ID=$(jget data.subscription_id)
[[ -n "$SUB_ID" ]] && ok "подписка $SUB_ID" || warn "подписку создать не вышло — сценарий продолжит вхолостую"
step "Что накопилось после последнего курсора"
req GET "$EVENTUS/events/pending?subscription_id=${SUB_ID}&limit=5" "" -H "Authorization: Bearer $EKEY"

# ── 6. eventus-sdk ─────────────────────────────────────────────────────────────
scene "6/8  eventus-sdk — тот же движок, но клиентом, без Postgres в зависимостях"
"$PY_EVENTUS_SDK" - <<SDK || fail "sdk сценарий упал"
import asyncio
from lzt_eventus_sdk import ManagementClient

async def main() -> None:
    async with ManagementClient("${EVENTUS}", api_key="${EKEY}") as mgmt:
        # list_subscriptions returns a Page envelope (items + total + limit + offset),
        # not a bare list — the engine paginates every collection route.
        page = await mgmt.list_subscriptions()
        print(f"   подписок на движке: {page.total}")
        for sub in page.items[:3]:
            print(f"   {sub.subscription_id}  transport={sub.transport}  events={len(sub.event_types)}")

asyncio.run(main())
SDK

# ── 7. flow + автобай ──────────────────────────────────────────────────────────
scene "7/8  auto-lzt — автопокупка Steam-аккаунтов, флоу целиком"
say "Граф: найти по потолку цены → проверить что нашлось → отрезать N → купить каждый."
say "count и max_price — параметры флоу, не константы в графе."
say "Фильтр цены применяет сам маркет — на testnet мок держит то же обещание:"
say "ни один лот дороже потолка в выдачу не попадёт, проверим это по трейсу."

step "Аккаунт, от чьего имени работает флоу"
if [[ "$MODE" == prod ]]; then
  ACCOUNT_TOKEN="${LZT_PROD_TOKEN:-}"
  [[ -n "$ACCOUNT_TOKEN" ]] || { fail "нет LZT_PROD_TOKEN в .env — прод-сценарий без токена невозможен"; ACCOUNT_TOKEN="none"; }
else
  ACCOUNT_TOKEN="testnet-fake-token"
fi
req POST "$FLOW/accounts/create" "{\"token\":\"$ACCOUNT_TOKEN\"}" -H "X-API-Key: $FKEY"
ACCOUNT_ID=$(jget id)
if [[ -n "$ACCOUNT_ID" ]]; then
  # Label it so a re-run can find this exact account again. Without that, the second run of the
  # demo hits "this token is already added", ends up with an empty id, and every step downstream
  # fails on a blank account_ref instead of reusing what is already there.
  req POST "$FLOW/accounts/$ACCOUNT_ID/label" '{"label":"demo"}' -H "X-API-Key: $FKEY"
else
  say "аккаунт с этим токеном уже заведён — ищем его по метке demo, а не плодим второй"
  req GET "$FLOW/accounts/list" "" -H "X-API-Key: $FKEY"
  ACCOUNT_ID=$(printf '%s' "$LAST_RESPONSE" | python3 -c 'import json,sys
try:
    rows = json.load(sys.stdin)
    rows = rows if isinstance(rows, list) else rows.get("items", [])
except Exception:
    rows = []
labelled = [r for r in rows if r.get("label") == "demo" and r.get("status") == "active"]
print(labelled[0]["id"] if labelled else "")')
fi
[[ -n "$ACCOUNT_ID" ]] && ok "аккаунт $ACCOUNT_ID" || fail "не удалось получить аккаунт для флоу"

step "Заливаем флоу автобая из каталога lzt-flows"
say "Узлы пинятся к только что созданному аккаунту (account_ref)."
say "Иначе рынок читался бы через общий пул токенов тенанта, где лежат аккаунты прошлых прогонов."
FLOW_SPEC=$(ACCOUNT_ID="$ACCOUNT_ID" python3 -c '
import json, os, sys, pathlib

spec = json.loads(pathlib.Path("lzt-flows/modules/steam-autobuy/flow.json").read_text(encoding="utf-8"))
account_id = os.environ["ACCOUNT_ID"]
for node in spec["nodes"]:
    if node["type"].startswith("market."):
        node["account_ref"] = account_id
json.dump(spec, sys.stdout, ensure_ascii=False)
')
req POST "$FLOW/flows/create" "$FLOW_SPEC" -H "X-API-Key: $FKEY"
FLOW_ID=$(jget flow_id)
[[ -n "$FLOW_ID" ]] || fail "флоу не создался"

step "Компиляция — граф превращается в неизменяемый FlowIR"
req POST "$FLOW/flows/$FLOW_ID/compile" '{}' -H "X-API-Key: $FKEY"

step "Запуск с параметрами: купить $BUY_COUNT штук по цене до $BUY_MAX_PRICE ₽"
# Deliberately false in BOTH modes, and the two reasons are different: on testnet a purchase costs
# nothing and a dry run would demo the wiring instead of the act, and in prod buying is the whole
# point of the run the operator just confirmed by typing БУДУ ПОКУПАТЬ. The safety here is
# MARKET_MODE, not this flag.
DRY=false
req POST "$FLOW/runs/create" \
  "{\"flow_id\":\"$FLOW_ID\",\"params\":{\"max_price\":$BUY_MAX_PRICE,\"count\":$BUY_COUNT,\"dry_run\":$DRY}}" \
  -H "X-API-Key: $FKEY"
RUN_ID=$(jget run_id)

step "Ждём воркер"
for _ in $(seq 1 30); do
  STATUS=$(curl -sS "$FLOW/runs/$RUN_ID/get" -H "X-API-Key: $FKEY" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("status",""))
except Exception: print("")')
  printf '  %s· статус: %s%s\n' "$c_dim" "$STATUS" "$c_reset"
  [[ "$STATUS" == completed || "$STATUS" == failed ]] && break
  sleep 2
done
[[ "$STATUS" == completed ]] && ok "прогон завершён" || fail "прогон в статусе '$STATUS'"

step "Трейс по шагам — что сделал каждый узел"
req GET "$FLOW/runs/$RUN_ID/trace" "" -H "X-API-Key: $FKEY"

step "Повторный запуск с тем же run_key — идемпотентность"
say "Тот же ключ обязан вернуть тот же run, а не купить второй раз."
req POST "$FLOW/runs/create" \
  "{\"flow_id\":\"$FLOW_ID\",\"run_key\":\"demo-idempotency\",\"params\":{\"max_price\":$BUY_MAX_PRICE,\"count\":$BUY_COUNT,\"dry_run\":true}}" \
  -H "X-API-Key: $FKEY"
FIRST_RUN=$(jget run_id)
req POST "$FLOW/runs/create" \
  "{\"flow_id\":\"$FLOW_ID\",\"run_key\":\"demo-idempotency\",\"params\":{\"max_price\":$BUY_MAX_PRICE,\"count\":$BUY_COUNT,\"dry_run\":true}}" \
  -H "X-API-Key: $FKEY"
SECOND_RUN=$(jget run_id)
if [[ "$FIRST_RUN" == "$SECOND_RUN" && -n "$FIRST_RUN" ]]; then
  ok "тот же run_id — второй покупки не было"
else
  fail "run_key не удержал идемпотентность: $FIRST_RUN vs $SECOND_RUN"
fi

# ── 8. mcp + панель ────────────────────────────────────────────────────────────
scene "8/8  lzt-mcp и панель"
step "Инструменты, которые видит ИИ-агент"
"$PY_MCP" - <<MCP || warn "mcp сценарий не отработал"
import asyncio
from lzt_dev_mcp.server import build_app

async def main() -> None:
    app = build_app()
    tools = await app.list_tools()
    print(f"   зарегистрировано инструментов: {len(tools)}")
    for tool in sorted(tools, key=lambda t: t.name)[:12]:
        print(f"   · {tool.name:<24} {tool.description or ''}"[:100])
    print("   …")

asyncio.run(main())
MCP

step "Панель — собрана и отдаётся"
req GET "$FLOW/panel/" "" -H "X-API-Key: $FKEY"

# ── итог ───────────────────────────────────────────────────────────────────────
printf '\n%s╔%s╗%s\n' "$c_cyan" "$_rule" "$c_reset"
if [[ $FAILURES == 0 ]]; then
  printf '%s║%s  %sДемо прошло целиком — сбоев нет%s\n' "$c_cyan" "$c_reset" "$c_bold$c_green" "$c_reset"
else
  printf '%s║%s  %sДемо закончило с ошибками: %s%s\n' "$c_cyan" "$c_reset" "$c_bold$c_red" "$FAILURES" "$c_reset"
fi
printf '%s║%s  режим %s · показаны: testnet · pylzt · eventus · eventus-sdk · flow · mcp · панель\n' "$c_cyan" "$c_reset" "$MODE"
printf '%s╚%s╝%s\n\n' "$c_cyan" "$_rule" "$c_reset"
exit $(( FAILURES > 0 ? 1 : 0 ))
