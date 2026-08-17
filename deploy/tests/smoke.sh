#!/usr/bin/env bash
# Smoke-test a published site. Two configs have pointed at this file for weeks;
# it did not exist, so nothing it promised was ever checked.
#
#   ./deploy/tests/smoke.sh https://open-lzt.chqcode.com
#
# Run it from anywhere, against anything — it only makes HTTP requests.
set -uo pipefail

# Аргумент ПЕРВЫЙ, переменная окружения вторая, и вторая появилась не для удобства:
# `BASE=https://... smoke.sh` — форма, которую пишут не думая, а прежняя версия её молча
# игнорировала и проверяла домен по умолчанию. Три прогона подряд отчитались зелёным про
# `open-lzt.dev`, проверив на самом деле соседний сайт, — и один раз покраснели ровно потому,
# что тот в этот момент перекатывался.
BASE="${1:-${BASE:-https://open-lzt.chqcode.com}}"
BASE="${BASE%/}"

c_ok=$'\033[32m'; c_bad=$'\033[31m'; c_off=$'\033[0m'
fails=0

# Цель называется ВСЛУХ, первой строкой. Проверка, которая не говорит, что именно она щупала,
# позволяет проверить не тот адрес и уйти довольным: именно так три зелёных отчёта про один
# домен оказались отчётами про другой.
printf '%s→ %s%s\n\n' "$c_ok" "$BASE" "$c_off"

# Every assertion prints what it expected and what it got: a red line that does
# not say the actual value sends the reader back to curl by hand.
check_code() {
  local path="$1" want="$2" got
  got="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE$path" || echo "000")"
  if [[ "$got" == "$want" ]]; then
    printf '%s ok %s %s -> %s\n' "$c_ok" "$c_off" "$path" "$got"
  else
    printf '%sFAIL%s %s -> %s (want %s)\n' "$c_bad" "$c_off" "$path" "$got" "$want"
    fails=$((fails + 1))
  fi
}

check_body() {
  local path="$1" needle="$2" body
  # Body into a variable, not piped into `grep -q`: grep exits at the first hit
  # and closes the pipe, curl dies of SIGPIPE with exit 23, and the assertion
  # fails on a file that was perfectly fine.
  #
  # A failed request is reported as a FAILED REQUEST, never as missing content.
  # Swallowing the error left an empty body and printed "does not contain",
  # which sends the reader to look at a file that is perfectly fine — seen once
  # on a transient connection error against a route that was serving correctly.
  if ! body="$(curl -sS --retry 2 --retry-all-errors "$BASE$path" 2>&1)"; then
    printf '%sFAIL%s %s could not be fetched: %s\n' "$c_bad" "$c_off" "$path" "${body:-no output}"
    fails=$((fails + 1))
    return
  fi
  if printf '%s' "$body" | grep -qF -- "$needle"; then
    printf '%s ok %s %s contains %s\n' "$c_ok" "$c_off" "$path" "$needle"
  else
    printf '%sFAIL%s %s does not contain %s\n' "$c_bad" "$c_off" "$path" "$needle"
    fails=$((fails + 1))
  fi
}

check_header() {
  local path="$1" name="$2" needle="$3" got
  got="$(curl -sSI "$BASE$path" | tr -d '\r' | grep -i "^$name:" | head -1)"
  if [[ "$got" == *"$needle"* ]]; then
    printf '%s ok %s %s %s\n' "$c_ok" "$c_off" "$path" "$got"
  else
    printf '%sFAIL%s %s %s: %s (want %s)\n' "$c_bad" "$c_off" "$path" "$name" "${got:-<absent>}" "$needle"
    fails=$((fails + 1))
  fi
}

printf '== %s ==\n' "$BASE"

# ── pages ────────────────────────────────────────────────────────────────────
check_code /             200
check_code /hosting      200   # without the trailing slash: `try_files $uri.html`
check_code /hosting/     200
check_code /en/hosting   200

# A missing page must answer 404, not a 200 with the pretty body: a monitor and
# a crawler read the code, not the words.
check_code /no-such-page 404

# ── install scripts ──────────────────────────────────────────────────────────
check_code /get/all.sh    200
check_code /get/update.sh 200
check_code /get/flow.sh   200
check_code /get/demo.sh   200
check_body /get/all.sh    '#!/usr/bin/env bash'
check_header /get/all.sh  content-type x-shellscript

# Nothing else under /get/ is published — including anything that tries to walk
# out of it. These are the traversal assertions the nginx config claims exist.
check_code /get/            404
check_code /get/../install.sh 404
check_code /get/v9.9.9/all.sh 404

# ── headers ──────────────────────────────────────────────────────────────────
check_header / strict-transport-security max-age
check_header / x-content-type-options nosniff
check_header / content-security-policy "frame-ancestors 'none'"

printf -- '----\n'
if (( fails )); then
  printf '%s%d check(s) failed%s\n' "$c_bad" "$fails" "$c_off"
  exit 1
fi
printf '%sall checks passed%s\n' "$c_ok" "$c_off"
