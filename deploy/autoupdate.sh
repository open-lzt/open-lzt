#!/usr/bin/env bash
# Rolling auto-updater for the open-lzt stand. For each ENABLED service config in
# deploy/autoupdate/<svc>.yaml it checks the tracked submodule branch for new commits and, when
# behind, rolls forward: fetch -> uv sync -> optional e2e gate -> migrate -> restart -> health gate,
# with automatic rollback to the previous commit if the health gate fails.
#
#   deploy/autoupdate.sh            # check + update every ENABLED service once
#   deploy/autoupdate.sh --dry-run  # report what it would do, change nothing
#
# Every service is DISABLED by default (enabled: false). See docs/AUTOUPDATE.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

UV=/root/.local/bin/uv
command -v "$UV" >/dev/null 2>&1 || UV=uv
export PATH="/root/.local/bin:$PATH"

c_reset=$'\033[0m'; c_cyan=$'\033[1;36m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'
c_red=$'\033[1;31m'; c_dim=$'\033[2m'; c_mag=$'\033[1;35m'
phase() { printf '\n%s▸ %s%s\n' "$c_mag" "$*" "$c_reset"; }
ok()    { printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
info()  { printf '  %s·%s %s%s%s\n' "$c_cyan" "$c_reset" "$c_dim" "$*" "$c_reset"; }
warn()  { printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
err()   { printf '  %s✗%s %s\n' "$c_red" "$c_reset" "$*"; }
act()   { if [[ $DRY_RUN == 1 ]]; then printf '   %s[dry-run] %s%s\n' "$c_dim" "$*" "$c_reset"; else eval "$@"; fi; }

# Flat-YAML value reader: cfg <file> <key> [default]
cfg() {
  local v
  v=$(sed -n "s/^${2}:[[:space:]]*//p" "$1" | head -1)
  v="${v%%#*}"; v="${v%\"}"; v="${v#\"}"; v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "${v:-${3:-}}"
}

[[ -f .env ]] && { set -a; . ./.env; set +a; }

# Repo is owned by the 'open-lzt' user; this runs as root — mark the repo + submodules trusted.
git config --global --get-all safe.directory 2>/dev/null | grep -qx "$ROOT" \
  || git config --global --add safe.directory "$ROOT"
for d in "$ROOT"/projects/*/; do git config --global --add safe.directory "${d%/}" 2>/dev/null || true; done

wait_health() { # url  |  ""(skip)  ; returns 0 healthy
  local url="$1" port="${2:-}"
  for _ in $(seq 1 30); do
    if [[ -n "$url" ]]; then
      curl -fsS --max-time 3 "$url" >/dev/null 2>&1 && return 0
    elif [[ -n "$port" ]]; then
      (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && { exec 3>&- 2>/dev/null || true; return 0; }
    else
      return 0
    fi
    sleep 2
  done
  return 1
}

run_migrate() { # flow|eventus|none — DSN sourced from the 0600 env file, never inline
  [[ "$1" == "none" || -z "$1" ]] && return 0
  case "$1" in
    flow)    act "( set -a; . deploy/env/flow.env; set +a; cd projects/flow && '$UV' run alembic upgrade head )" ;;
    eventus) act "( set -a; . deploy/env/eventus.env; set +a; LZT_DATABASE_URL=\"\${LZT_DATABASE_URL/postgresql:/postgresql+asyncpg:}\"; cd projects/eventus && '$UV' run alembic upgrade head )" ;;
    *) : ;;
  esac
}

restart_units() { for u in $1; do act "systemctl restart $u"; done; }

update_one() {
  local file="$1" name; name="$(basename "$file" .yaml)"
  [[ "$(cfg "$file" enabled false)" == "true" ]] || { info "$name: disabled — skipped"; return 0; }

  local sub branch units migrate health_url health_port e2e rollback verify
  sub=$(cfg "$file" submodule); branch=$(cfg "$file" branch main)
  units=$(cfg "$file" units); migrate=$(cfg "$file" migrate none)
  health_url=$(cfg "$file" health_url); health_port=$(cfg "$file" health_port)
  e2e=$(cfg "$file" e2e_cmd); rollback=$(cfg "$file" rollback_on_failure true)
  verify=$(cfg "$file" verify false)

  phase "$name"
  [[ -d "$sub/.git" || -f "$sub/.git" ]] || { err "$name: submodule $sub not initialised"; return 1; }

  git -C "$sub" fetch --quiet origin "$branch" 2>/dev/null || { err "$name: fetch failed"; return 1; }
  local cur new; cur=$(git -C "$sub" rev-parse HEAD); new=$(git -C "$sub" rev-parse "origin/$branch")
  if [[ "$cur" == "$new" ]]; then ok "$name: up to date (${cur:0:8})"; return 0; fi
  info "$name: ${cur:0:8} -> ${new:0:8}"

  # Trust gate: with verify:true only a GPG-signed commit/tag is accepted before we run its code
  # as a privileged rollout. Prevents a hijacked remote / MITM from shipping arbitrary code.
  if [[ "$verify" == "true" ]] && ! git -C "$sub" verify-commit "$new" 2>/dev/null; then
    err "$name: signature verification FAILED for ${new:0:8} — refusing update"
    return 1
  fi

  act "git -C '$sub' checkout --quiet '$new'"
  act "'$UV' sync --project '$sub' $([[ $name == eventus ]] && echo '--extra engine')"
  act "chown -R open-lzt:open-lzt '$sub' 2>/dev/null || true"

  if [[ -n "$e2e" ]]; then
    info "$name: e2e gate"
    if ! act "$e2e"; then
      err "$name: e2e gate failed — aborting, keeping ${cur:0:8}"
      act "git -C '$sub' checkout --quiet '$cur'"; act "'$UV' sync --project '$sub'"
      return 1
    fi
  fi

  run_migrate "$migrate"
  restart_units "$units"

  if [[ $DRY_RUN == 0 ]] && ! wait_health "$health_url" "$health_port"; then
    err "$name: health gate failed after update"
    if [[ "$rollback" == "true" ]]; then
      warn "$name: rolling back to ${cur:0:8}"
      git -C "$sub" checkout --quiet "$cur"; "$UV" sync --project "$sub" >/dev/null 2>&1 || true
      restart_units "$units"
      wait_health "$health_url" "$health_port" && ok "$name: rolled back, healthy" || err "$name: STILL unhealthy after rollback"
    fi
    return 1
  fi
  ok "$name: updated to ${new:0:8} and healthy"
}

phase "open-lzt auto-update ($([[ $DRY_RUN == 1 ]] && echo dry-run || echo live))"
rc=0
CONFIG_DIR="${AUTOUPDATE_CONFIG_DIR:-deploy/autoupdate}"
for f in "$CONFIG_DIR"/*.yaml; do update_one "$f" || rc=1; done
exit $rc
