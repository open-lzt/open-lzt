#!/usr/bin/env bash
# Build the site and publish it. Idempotent: safe to re-run, and a second run in
# a row changes nothing.
#
#   sudo ./deploy-site.sh                          # build, publish, reload nginx
#   sudo ./deploy-site.sh --dry-run                # print what it would do
#   sudo DOMAIN=open-lzt.dev ./deploy-site.sh      # publish under another domain
#
# Runs ON THE HOST that serves the site, from the clone at /opt/open-lzt.
#
# The domain lives in ONE place — the variable below. It used to be typed into
# the nginx config, this script and three installers separately, and production
# ended up on a different one than all four; the config in this repo could not
# be installed at all without replacing a working one that had drifted five
# fixes ahead of it.
#
# The site is static, so publishing is a directory swap: the new build is
# assembled beside the live one and only then moved into place, so a failed
# build never leaves a half-copied site being served. The previous one is kept
# as <root>.prev — that is the rollback.
set -euo pipefail

DOMAIN="${DOMAIN:-open-lzt.dev}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_SRC="$REPO_DIR/site"
WEB_ROOT="/var/www/$DOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN.conf"
SNIPPET_DIR="/etc/nginx/snippets"
TEMPLATE="$REPO_DIR/deploy/nginx/open-lzt-site.conf.template"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_off=$'\033[0m'
say()  { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s!!%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
run()  { if (( DRY_RUN )); then printf '   would run: %s\n' "$*"; else "$@"; fi; }

[[ $EUID -eq 0 || $DRY_RUN -eq 1 ]] || { warn "run as root (it writes to /var/www and reloads nginx)"; exit 1; }
[[ -d "$SITE_SRC" ]] || { warn "no $SITE_SRC — this clone has no site sources to build"; exit 1; }
[[ -f "$TEMPLATE" ]] || { warn "no $TEMPLATE"; exit 1; }

say "domain: $DOMAIN"

# ── build ────────────────────────────────────────────────────────────────────
say "building the site"
if (( DRY_RUN )); then
  printf '   would run: npm ci && npm run build (in %s)\n' "$SITE_SRC"
else
  cd "$SITE_SRC"
  # `npm ci` over `npm install`: the lockfile is the contract, and a deploy is
  # the worst place to silently pick up a newer transitive dependency.
  npm ci --no-audit --no-fund
  npm run build
  [[ -f "$SITE_SRC/out/index.html" ]] || { warn "build produced no out/index.html"; exit 1; }
  cd "$REPO_DIR"
fi

# ── publish ──────────────────────────────────────────────────────────────────
say "publishing to $WEB_ROOT"
if (( DRY_RUN )); then
  printf '   would run: assemble %s.new, rotate %s -> %s.prev, move new into place\n' \
    "$WEB_ROOT" "$WEB_ROOT" "$WEB_ROOT"
else
  rm -rf "$WEB_ROOT.new"
  mkdir -p "$WEB_ROOT.new"
  cp -a "$SITE_SRC/out/." "$WEB_ROOT.new/"
  chown -R www-data:www-data "$WEB_ROOT.new"
  # The swap is two renames with nothing between them that can fail slowly: a
  # visitor either gets the whole old site or the whole new one.
  rm -rf "$WEB_ROOT.prev"
  [[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "$WEB_ROOT.prev"
  mv "$WEB_ROOT.new" "$WEB_ROOT"
fi

# ── nginx ────────────────────────────────────────────────────────────────────
say "installing nginx config"
run mkdir -p "$SNIPPET_DIR"
run install -m 0644 "$REPO_DIR/deploy/nginx/snippets/open-lzt-script.conf" "$SNIPPET_DIR/open-lzt-script.conf"

if (( DRY_RUN )); then
  printf '   would run: render %s with DOMAIN=%s -> %s\n' "$TEMPLATE" "$DOMAIN" "$NGINX_CONF"
  printf '   would run: nginx -t && ln -sfn %s %s && systemctl reload nginx\n' "$NGINX_CONF" "$NGINX_LINK"
else
  rendered="$(mktemp)"
  # The domain is the only substitution, so a plain replace is the whole
  # templating engine. `|` as the delimiter: a domain has dots, never a pipe.
  sed "s|@@DOMAIN@@|$DOMAIN|g" "$TEMPLATE" > "$rendered"
  grep -q '@@' "$rendered" && { warn "unsubstituted placeholder left in the rendered config"; rm -f "$rendered"; exit 1; }
  install -m 0644 "$rendered" "$NGINX_CONF"
  rm -f "$rendered"

  # Validated BEFORE the symlink exists, not after. A config linked into
  # sites-enabled and only then found broken stays there: this reload fails, and
  # so does the next reload by anyone else, for a reason that has nothing to do
  # with what they changed.
  if ! nginx -t -c /etc/nginx/nginx.conf 2>&1 | tail -2; then
    warn "config invalid — not linked, nothing reloaded, the running site is untouched"
    exit 1
  fi
  ln -sfn "$NGINX_CONF" "$NGINX_LINK"
  if ! nginx -t; then
    warn "config invalid once enabled — unlinking and leaving the running site alone"
    rm -f "$NGINX_LINK"
    exit 1
  fi
  systemctl reload nginx
fi

say "done"
if (( DRY_RUN )); then
  printf '   (dry run — nothing above actually happened)\n'
else
  say "verifying"
  "$REPO_DIR/deploy/tests/smoke.sh" "https://$DOMAIN"
  printf '   rollback: mv %s %s.bad && mv %s.prev %s\n' "$WEB_ROOT" "$WEB_ROOT" "$WEB_ROOT" "$WEB_ROOT"
fi
