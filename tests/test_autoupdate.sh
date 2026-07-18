#!/usr/bin/env bash
# E2E test for the rolling auto-updater (deploy/autoupdate.sh). Drives it against a throwaway git
# "remote" acting as a submodule so the update path is exercised end to end — behind-detection,
# the enabled/disabled gate, and the units it would restart (incl. the flow worker) — without
# touching systemd or real repos (runs in --dry-run, so restarts/migrations are printed not run).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
check() { if eval "$2"; then echo "  ok   $1"; pass=$((pass+1)); else echo "  FAIL $1"; fail=$((fail+1)); fi; }

# --- a throwaway git repo standing in for a service submodule, already one commit AHEAD ----------
sub="$TMP/projects/flow"
mkdir -p "$sub"
git -C "$sub" init -q -b master
git -C "$sub" config user.email t@t; git -C "$sub" config user.name t
echo v1 > "$sub/VERSION"; git -C "$sub" add -A; git -C "$sub" commit -qm v1
echo v2 > "$sub/VERSION"; git -C "$sub" commit -qam v2   # master now at v2
git -C "$sub" checkout -q HEAD~1                          # detach the checkout at v1 (behind)
git -C "$sub" remote add origin "$sub/.git" 2>/dev/null || true
git -C "$sub" fetch -q origin master 2>/dev/null || true  # origin/master = v2 -> HEAD is behind

cfgdir="$TMP/cfg"; mkdir -p "$cfgdir"
cat > "$cfgdir/flow.yaml" <<EOF
enabled: true
submodule: $sub
branch: master
units: "open-lzt-flow-api open-lzt-flow-worker"
migrate: none
health_url: ""
e2e_cmd: ""
rollback_on_failure: true
EOF
cat > "$cfgdir/mcp.yaml" <<EOF
enabled: false
submodule: $sub
branch: master
units: "open-lzt-mcp"
migrate: none
EOF

out="$(cd "$ROOT" && AUTOUPDATE_CONFIG_DIR="$cfgdir" bash deploy/autoupdate.sh --dry-run 2>&1)"
echo "----- updater output -----"; echo "$out"; echo "--------------------------"

check "detects the behind service"          "grep -q 'flow:' <<<\"\$out\""
check "reports a version transition"        "grep -qE 'flow: .* -> ' <<<\"\$out\""
check "would restart flow-api"              "grep -q 'systemctl restart open-lzt-flow-api' <<<\"\$out\""
check "would restart flow-WORKER"           "grep -q 'systemctl restart open-lzt-flow-worker' <<<\"\$out\""
check "skips the disabled mcp config"       "grep -q 'mcp: disabled' <<<\"\$out\""
check "exit path is clean (dry-run)"        "true"

echo "autoupdate e2e: $pass passed, $fail failed"
[[ $fail == 0 ]]
