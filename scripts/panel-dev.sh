#!/usr/bin/env bash
# Bring up the panel for local work: the flow API on :8000 and vite on :5173.
#
# Exits non-zero if either fails to bind, rather than leaving one half running and looking healthy —
# a vite dev server with no API behind it renders an empty panel and no error.
#
#   ./scripts/panel-dev.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW="$ROOT/projects/flow"
API_PORT="${API_PORT:-8000}"
VITE_PORT="${VITE_PORT:-5173}"

c_green=$'\033[1;32m'; c_red=$'\033[1;31m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
ok()   { printf '%s  ✓ %s%s\n' "$c_green" "$*" "$c_reset"; }
die()  { printf '%s  ✗ %s%s\n' "$c_red" "$*" "$c_reset" >&2; exit 1; }
info() { printf '%s  · %s%s\n' "$c_dim" "$*" "$c_reset"; }

pids=()
cleanup() { for pid in "${pids[@]:-}"; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM

wait_for_port() { # port name timeout
  local port="$1" name="$2" deadline=$((SECONDS + ${3:-30}))
  while (( SECONDS < deadline )); do
    # bash's /dev/tcp needs no netcat, which is not installed everywhere.
    (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && { exec 3<&-; ok "$name on :$port"; return 0; }
    sleep 0.5
  done
  die "$name did not bind :$port"
}

command -v uv >/dev/null || die "uv not found"
command -v pnpm >/dev/null || die "pnpm not found (corepack enable)"

info "starting the flow API…"
( cd "$FLOW" && uv run python dev.py --port "$API_PORT" ) &
pids+=($!)
wait_for_port "$API_PORT" "flow API" 60

info "starting vite…"
( cd "$FLOW/frontend" && pnpm run dev --port "$VITE_PORT" ) &
pids+=($!)
wait_for_port "$VITE_PORT" "vite" 60

printf '\n  panel: %shttp://127.0.0.1:%s%s\n  (Ctrl-C stops both)\n\n' "$c_green" "$VITE_PORT" "$c_reset"
wait -n
die "one of the two processes exited"
