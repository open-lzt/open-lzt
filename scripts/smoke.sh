#!/usr/bin/env bash
# Cross-service smoke test: drives the full chain over HTTP against a RUNNING open-lzt stack
# in testnet mode. Exits non-zero on the first failure. Intended to run right after install.sh on
# the server, and in CI against the compose stack.
#
# Port map (see README.md): testnet 8765 · eventus 27543 · flow 8000 · mcp-http 8770.
set -euo pipefail

TESTNET="${TESTNET_BASE_URL:-http://127.0.0.1:8765}"
EVENTUS="${EVENTUS_BASE_URL:-http://127.0.0.1:27543}"
FLOW="${FLOW_BASE_URL:-http://127.0.0.1:8000}"
FLOW_API_KEY="${LZT_FLOW_API_KEY:-}"
EVENTUS_KEY="${LZT_ADMIN_API_KEY:-}"

say() { printf '\033[1;36m[smoke]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[smoke:FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

req() { # method url [auth-header]
  local method="$1" url="$2" auth="${3:-}"
  if [[ -n "$auth" ]]; then
    curl -fsS -X "$method" -H "$auth" "$url"
  else
    curl -fsS -X "$method" "$url"
  fi
}

say "1/4 testnet health"
req GET "$TESTNET/testnet/health" | grep -q '"status"' || fail "testnet unhealthy"

say "2/4 testnet reset (clean state)"
req POST "$TESTNET/testnet/reset" >/dev/null || fail "testnet reset failed"

say "3/4 eventus readiness"
req GET "$EVENTUS/readyz" >/dev/null || fail "eventus not ready"

say "4/4 flow API reachable"
flow_auth=""
[[ -n "$FLOW_API_KEY" ]] && flow_auth="X-API-Key: $FLOW_API_KEY"
req GET "$FLOW/catalog/list" "$flow_auth" >/dev/null || fail "flow catalog unreachable"

say "OK — testnet + eventus + flow all up and talking (testnet-mode, no real market hit)"
