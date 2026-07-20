#!/usr/bin/env bash
# Rolling update of a running open-lzt stand: pull latest, re-sync deps, migrate, restart services.
# Health-gated: if a service fails to come healthy, the previous systemd unit state is left running
# for inspection. Idempotent; safe to re-run.
#
#   sudo ./update.sh
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"
UV=/root/.local/bin/uv
export PATH="/root/.local/bin:$PATH"

c_cyan=$'\033[1;36m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_reset=$'\033[0m'
phase() { printf '\n%s==> %s%s\n' "$c_cyan" "$*" "$c_reset"; }
ok()    { printf '%s  ✓ %s%s\n' "$c_green" "$*" "$c_reset"; }
warn()  { printf '%s  ! %s%s\n' "$c_yellow" "$*" "$c_reset"; }

phase "1/5 Pull latest"
if [[ -d .git ]]; then
  # Tree is owned by the 'open-lzt' service user; this runs as root, so git needs it marked trusted.
  git config --global --get-all safe.directory 2>/dev/null | grep -qx "$INSTALL_DIR" \
    || git config --global --add safe.directory "$INSTALL_DIR"
  for d in "$INSTALL_DIR"/projects/*/; do git config --global --add safe.directory "${d%/}" 2>/dev/null || true; done
  git pull --ff-only || warn "monorepo pull skipped (diverged?)"
  # Advance each project submodule to the latest commit of its tracked branch (.gitmodules),
  # not just the pinned pointer — this is what actually pulls new project code onto the stand.
  git submodule update --init --remote --recursive || warn "submodule update had issues"
else
  warn "not a git checkout — skipping pull"
fi

# shellcheck disable=SC1091
set -a && source .env && set +a

phase "2/5 Re-sync dependencies"
# Four independent projects — run concurrently instead of paying network latency four times over
# (same rationale as install.sh's sync_projects).
sync_projects() {
  local -a projects=(
    "testnet|--project projects/testnet"
    "eventus|--project projects/eventus --extra engine"
    "flow|--project projects/flow"
    "mcp|--project projects/mcp"
  )
  local -a pids=() names=()
  local entry name args logfile
  for entry in "${projects[@]}"; do
    name="${entry%%|*}"; args="${entry#*|}"
    logfile="/tmp/open-lzt-update-sync-${name}.log"
    # shellcheck disable=SC2086 — args is a deliberate word-split argument list
    "$UV" sync $args >"$logfile" 2>&1 &
    pids+=("$!"); names+=("$name")
  done
  local i failed=0
  for i in "${!pids[@]}"; do
    if wait "${pids[$i]}"; then
      ok "${names[$i]} synced"
    else
      failed=1
      warn "${names[$i]} FAILED — tail of /tmp/open-lzt-update-sync-${names[$i]}.log:"
      tail -15 "/tmp/open-lzt-update-sync-${names[$i]}.log" | sed 's/^/      /'
    fi
  done
  return $failed
}
export UV_CONCURRENT_DOWNLOADS="${UV_CONCURRENT_DOWNLOADS:-16}"
sync_projects && ok "deps synced" || { warn "dependency sync failed — see logs above"; exit 1; }

phase "2b/5 Rebuild the panel"
# Rebuilt on every update because the pull above may have changed frontend source; nginx serves the
# built files straight off disk, so a stale dist would keep showing the previous version with no
# other symptom. A host with no node still updates — it just keeps whatever panel it had.
if command -v node >/dev/null 2>&1; then
  # pnpm on a stock Debian/Ubuntu node package is a corepack SHIM that asks "Do you want to
  # continue?" on every invocation unless this is set — see install.sh's build_panel for the
  # full rationale. Same fix here: prompt disabled, stdin closed on every pnpm call.
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  PNPM="$(command -v pnpm 2>/dev/null || { corepack enable >/dev/null 2>&1 </dev/null; command -v pnpm 2>/dev/null; } || true)"
  if [[ -n "${PNPM:-}" ]]; then
    ( cd projects/flow/frontend \
        && "$PNPM" install --frozen-lockfile --prefer-offline </dev/null \
        && "$PNPM" run build </dev/null ) \
      && ok "panel rebuilt" || warn "panel rebuild failed — previous build still served"
  else
    warn "pnpm not found — panel not rebuilt"
  fi
else
  warn "node not found — panel not rebuilt"
fi

phase "3/5 Migrations"
# DSN read from the 0600 env file, not passed inline (keeps the password out of ps).
( set -a; . "$INSTALL_DIR/deploy/env/eventus.env"; set +a
  LZT_DATABASE_URL="${LZT_DATABASE_URL/postgresql:/postgresql+asyncpg:}"
  cd projects/eventus && "$UV" run alembic upgrade head )
( set -a; . "$INSTALL_DIR/deploy/env/flow.env"; set +a
  cd projects/flow && "$UV" run alembic upgrade head )
ok "migrated"

phase "4/5 Restart services"
install -m644 deploy/systemd/open-lzt-*.service /etc/systemd/system/
systemctl daemon-reload
chown -R open-lzt:open-lzt "$INSTALL_DIR" 2>/dev/null || true
for svc in testnet eventus flow-api flow-worker mcp; do
  systemctl restart "open-lzt-${svc}.service"
done
ok "restarted"

phase "5/5 Health check"
for _ in $(seq 1 20); do bash scripts/healthcheck.sh >/dev/null 2>&1 && break; sleep 2; done
if bash scripts/healthcheck.sh; then
  ok "update complete — all healthy"
else
  warn "some services unhealthy — inspect: journalctl -u open-lzt-<svc> -n 50"
  exit 1
fi
