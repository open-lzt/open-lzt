#!/usr/bin/env bash
# Polls each open-lzt service's liveness endpoint. Non-zero exit if any is down.
set -euo pipefail

TESTNET_PORT="${TESTNET_PORT:-8765}"
EVENTUS_PORT="${EVENTUS_PORT:-27543}"
FLOW_PORT="${FLOW_PORT:-8000}"
MCP_PORT="${MCP_PORT:-8770}"

c_green=$'\033[1;32m'; c_red=$'\033[1;31m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
fail=0
check() { # name url
  if curl -fsS --max-time 5 "$2" >/dev/null 2>&1; then
    printf '  %s✓%s %-14s %s%s%s\n' "$c_green" "$c_reset" "$1" "$c_dim" "$2" "$c_reset"
  else
    printf '  %s✗%s %-14s %s%s%s\n' "$c_red" "$c_reset" "$1" "$c_dim" "$2" "$c_reset"; fail=1
  fi
}
check_port() { # name port
  if (exec 3<>"/dev/tcp/127.0.0.1/$2") 2>/dev/null; then
    printf '  %s✓%s %-14s %s:%s listening%s\n' "$c_green" "$c_reset" "$1" "$c_dim" "$2" "$c_reset"; exec 3>&- 2>/dev/null || true
  else
    printf '  %s✗%s %-14s %s:%s down%s\n' "$c_red" "$c_reset" "$1" "$c_dim" "$2" "$c_reset"; fail=1
  fi
}

check testnet "http://127.0.0.1:${TESTNET_PORT}/testnet/health"
check eventus "http://127.0.0.1:${EVENTUS_PORT}/healthz"
check flow    "http://127.0.0.1:${FLOW_PORT}/catalog/list"
check_port mcp "${MCP_PORT}"

exit $fail
