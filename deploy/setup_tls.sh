#!/usr/bin/env bash
# Set up nginx + TLS in front of the stand. Called by install.sh; can be re-run standalone.
#
#   deploy/setup_tls.sh <domain> <email> <mode> [flow_port]
#     mode = letsencrypt  -> nginx + certbot (Let's Encrypt) for <domain>
#          = selfsigned   -> nginx + a self-signed cert for <domain> or, if empty, this host's IP
#
# nginx terminates TLS and reverse-proxies to the loopback services:
#   /            -> flow API   (127.0.0.1:<flow_port>)
#   /eventus/    -> eventus    (127.0.0.1:27543)
set -euo pipefail

DOMAIN="${1:-}"; EMAIL="${2:-}"; MODE="${3:-none}"; FLOW_PORT="${4:-8000}"
EVENTUS_PORT="${EVENTUS_PORT:-27543}"
c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
ok(){ printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
warn(){ printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die(){ printf '  %s✗ %s%s\n' "$c_red" "$*" "$c_reset" >&2; exit 1; }

[[ "$MODE" == "none" ]] && { ok "TLS mode 'none' — nothing to do"; exit 0; }
command -v apt-get >/dev/null || die "setup_tls needs apt (Debian/Ubuntu)"

apt-get update -qq
# gettext-base carries envsubst, which renders deploy/nginx/panel.conf.
apt-get install -y -qq nginx gettext-base
if command -v ufw >/dev/null 2>&1; then ufw allow 80/tcp >/dev/null 2>&1 || true; ufw allow 443/tcp >/dev/null 2>&1 || true; fi

SITE=/etc/nginx/sites-available/open-lzt
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PANEL_ROOT="${PANEL_ROOT:-$(cd "$HERE/.." && pwd)/projects/flow/frontend/dist}"

# The location blocks live in deploy/nginx/panel.conf rather than in a heredoc here, because the
# SSE-critical directives in them (proxy_buffering off and friends) are the kind of thing that gets
# silently dropped when someone edits a shell heredoc. Only ${PANEL_ROOT}, ${FLOW_PORT} and
# ${EVENTUS_PORT} are substituted; every $-variable nginx itself owns is left alone.
proxy_block() {
  if [[ -d "$PANEL_ROOT" ]]; then
    PANEL_ROOT="$PANEL_ROOT" FLOW_PORT="$FLOW_PORT" EVENTUS_PORT="$EVENTUS_PORT" \
      envsubst '${PANEL_ROOT} ${FLOW_PORT} ${EVENTUS_PORT}' < "$HERE/nginx/panel.conf"
  else
    # No built panel (install.sh skipped the build, or this is an API-only host): serve the API at
    # the root the way this stand did before the panel existed, rather than serving a 404 page.
    warn "panel not built at $PANEL_ROOT — serving the API at / instead"
    cat <<NGINX
    location / {
        proxy_pass http://127.0.0.1:${FLOW_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /eventus/ {
        proxy_pass http://127.0.0.1:${EVENTUS_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
NGINX
  fi
}
enable_site() {
  ln -sf "$SITE" /etc/nginx/sites-enabled/open-lzt
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
}

if [[ "$MODE" == "letsencrypt" ]]; then
  [[ -n "$DOMAIN" ]] || die "letsencrypt mode needs a domain"
  [[ -n "$EMAIL" ]]  || die "letsencrypt mode needs an email"
  apt-get install -y -qq certbot python3-certbot-nginx
  # Plain HTTP server first so certbot --nginx can attach the cert and add the 443 block itself.
  { echo "server {"; echo "    listen 80;"; echo "    server_name ${DOMAIN};"; proxy_block; echo "}"; } > "$SITE"
  enable_site
  if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect; then
    ok "Let's Encrypt cert issued for ${DOMAIN} — https://${DOMAIN}"
    ok "auto-renewal is handled by the certbot systemd timer"
  else
    warn "certbot failed (is ${DOMAIN}'s DNS pointed at this server and port 80 reachable?)"
    warn "the site is up on plain HTTP; re-run once DNS resolves"
  fi

elif [[ "$MODE" == "selfsigned" ]]; then
  CN="$DOMAIN"; SAN="DNS:${DOMAIN}"
  if [[ -z "$DOMAIN" ]]; then
    IP="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
    CN="$IP"; SAN="IP:${IP}"
  fi
  TLS_DIR=/etc/open-lzt/tls; install -d -m700 "$TLS_DIR"
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout "$TLS_DIR/key.pem" -out "$TLS_DIR/cert.pem" \
    -subj "/CN=${CN}" -addext "subjectAltName=${SAN}" >/dev/null 2>&1
  chmod 600 "$TLS_DIR/key.pem"
  { echo "server {"; echo "    listen 80;"; echo "    server_name ${CN};"; echo "    return 301 https://\$host\$request_uri;"; echo "}";
    echo "server {";
    echo "    listen 443 ssl;";
    echo "    server_name ${CN};";
    echo "    ssl_certificate     ${TLS_DIR}/cert.pem;";
    echo "    ssl_certificate_key ${TLS_DIR}/key.pem;";
    proxy_block;
    echo "}"; } > "$SITE"
  enable_site
  ok "self-signed cert installed for ${CN} — https://${CN} (browsers will warn; it's self-signed)"
fi
