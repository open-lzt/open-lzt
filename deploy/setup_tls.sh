#!/usr/bin/env bash
# Set up nginx (and TLS) in front of the stand. Called by install.sh; can be re-run standalone.
# The single place that writes the nginx site — install.sh no longer renders one of its own.
#
#   deploy/setup_tls.sh <domain> <email> <mode> [flow_port]
#     mode = letsencrypt  -> nginx + certbot (Let's Encrypt) for <domain>
#          = selfsigned   -> nginx + a self-signed cert for <domain> or, if empty, this host's IP
#          = none         -> nginx serves the panel over plain HTTP only, no cert
#
# nginx terminates TLS and reverse-proxies to the loopback services:
#   /            -> flow API   (127.0.0.1:<flow_port>)
#   /eventus/    -> eventus    (127.0.0.1:27543)
set -euo pipefail

DOMAIN="${1:-}"; EMAIL="${2:-}"; MODE="${3:-none}"; FLOW_PORT="${4:-8000}"
EVENTUS_PORT="${EVENTUS_PORT:-27543}"
c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
# Diagnostics go to stderr, never stdout. `proxy_block` runs inside `{ ... } > "$SITE"`, so a
# helper printing to stdout writes its own warning INTO the nginx config — which is exactly how
# "panel not built" became "nginx rejected the generated site" and a refused connection.
ok(){ printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$*" >&2; }
warn(){ printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$*" >&2; }
die(){ printf '  %s✗ %s%s\n' "$c_red" "$*" "$c_reset" >&2; exit 1; }

command -v apt-get >/dev/null || die "setup_tls needs apt (Debian/Ubuntu)"

# A fresh VPS is still running unattended-upgrades when the installer reaches this phase, and
# it holds the dpkg lock. This step used to be the one that lost that race: every service was
# up, and the panel was the single thing missing. Wait for the lock instead of failing.
export DEBIAN_FRONTEND=noninteractive
# `apt-get` fails instantly when the dpkg lock is held (unlike `apt`, which waits 120s), and a
# fresh VPS runs unattended-upgrades for its first minutes. A wrapper would only cover OUR
# calls — get.docker.com and the NodeSource script run their own apt and are just as exposed.
# One config drop-in covers every apt in the run, ours and theirs.
apt_wait_setup() {
  local f=/etc/apt/apt.conf.d/99-open-lzt-lock-timeout
  [[ -w /etc/apt/apt.conf.d ]] || return 0
  echo "DPkg::Lock::Timeout \"${APT_WAIT:-600}\";" > "$f" 2>/dev/null || true
}
apt_wait_setup

# Who is listening on a port, named. The previous one-liner (`ss | grep -E ':(80|443)\s'`) matched
# nothing on the run that needed it most — the column is `0.0.0.0:80` followed by more fields, and
# the anchor never lined up. Match the address column itself and print the process.
# True when someone other than nginx already holds the port. A docker-proxy on :80 is common on
# a box that also runs containers, and it must not cost the operator the whole panel: nginx can
# still serve 443, so the plain-HTTP redirect server is simply left out of the config.
port_taken_by_other() {
  local p="$1"
  [[ -n "$(ss -ltnp 2>/dev/null | awk -v pat=":${p}\$" '$4 ~ pat {print $NF}' | grep -v nginx || true)" ]]
}

port_holders() {
  local p="$1" out
  out="$(ss -ltnp 2>/dev/null | awk -v pat=":${p}\$" '$4 ~ pat {print $4"  "$NF}')"
  [[ -n "$out" ]] || out="$(command -v fuser >/dev/null && fuser -n tcp "$p" 2>/dev/null || true)"
  [[ -n "$out" ]] && printf '      порт %s занят: %s\n' "$p" "$(printf '%s' "$out" | tr '\n' ' ')"
  return 0
}

# nginx cannot bind a port someone else already holds, and `nginx -t` never notices — a stock
# apache2 on the image is the usual culprit. Say so BEFORE writing a config and failing to start.
for _p in 80 443; do
  _busy="$(ss -ltnp 2>/dev/null | awk -v pat=":${_p}\$" '$4 ~ pat {print $NF}' | grep -v nginx || true)"
  if [[ -n "$_busy" ]]; then
    warn "порт ${_p} уже занят не-nginx процессом:"
    port_holders "$_p" >&2
    case "$_busy" in
      *apache2*) warn "освободить: systemctl disable --now apache2" ;;
      *caddy*)   warn "освободить: systemctl disable --now caddy" ;;
      *httpd*)   warn "освободить: systemctl disable --now httpd" ;;
      *)         warn "освободить порт и повторить: bash deploy/setup_tls.sh …" ;;
    esac
  fi
done

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
    # Same SSE treatment panel.conf gives /api/tasks/stream — without it nginx buffers the stream
    # and the client connects successfully, then receives nothing. Here the API sits at the root,
    # so the stream paths carry no /api prefix.
    location = /tasks/stream {
        proxy_pass http://127.0.0.1:${FLOW_PORT}/tasks/stream;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 3600s;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location ~ ^/runs/[^/]+/stream$ {
        proxy_pass http://127.0.0.1:${FLOW_PORT};
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 3600s;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
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
# A previous install.sh wrote its own separate site (open-lzt-panel); this is now the only site,
# so any leftover copy of that one is cleaned up here too, not just the stock default.
enable_site() {
  ln -sf "$SITE" /etc/nginx/sites-enabled/open-lzt
  rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/open-lzt-panel
  local test_output
  if test_output="$(nginx -t 2>&1)"; then
    # Both branches failing used to be the LAST command of this function, so `set -e` killed the
    # script with no message at all — the operator saw a verdict and no cause. nginx -t passing
    # says nothing about starting: the bind happens at runtime, so a port already taken or a
    # masked unit fails only here.
    if ! systemctl reload nginx >/dev/null 2>&1 && ! systemctl restart nginx >/dev/null 2>&1; then
      systemctl status nginx --no-pager -n 5 2>&1 | sed 's/^/      /' >&2
      port_holders 80 >&2; port_holders 443 >&2
      die "nginx не запустился (конфиг валиден) — вывод systemctl выше"
    fi
  else
    rm -f /etc/nginx/sites-enabled/open-lzt
    # Print what nginx actually said. Swallowing it left the operator with a refused connection
    # and nothing to act on.
    printf '%s\n' "$test_output" >&2
    warn "конфиг сохранён в $SITE — строка с ошибкой названа выше"
    die "nginx отверг конфиг: сайт не включён, панель не раздаётся"
  fi
}
# nginx -t does not open sockets, so a `listen [::]:80` on a host without IPv6 passes the config
# test and then fails the actual start with "Address family not supported by protocol" — a valid
# config that will not run. Emit the v6 lines only where there is a v6 stack.
listen6() {  # $1 = "80 default_server" | "443 ssl default_server"
  [[ -f /proc/net/if_inet6 ]] || return 0
  local port="${1%% *}" rest="${1#* }"
  [[ "$rest" == "$1" ]] && rest=""
  echo "    listen [::]:${port}${rest:+ $rest};"
}
host_ip() { curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'; }

if [[ "$MODE" == "none" ]]; then
  { echo "server {"; echo "    listen 80 default_server;"; listen6 "80 default_server";
    echo "    server_name _;"; proxy_block; echo "}"; } > "$SITE"
  enable_site
  ok "panel served at http://$(host_ip)/ (no TLS — pass --tls selfsigned for HTTPS)"

elif [[ "$MODE" == "letsencrypt" ]]; then
  [[ -n "$DOMAIN" ]] || die "letsencrypt mode needs a domain"
  [[ -n "$EMAIL" ]]  || die "letsencrypt mode needs an email"
  apt-get install -y -qq certbot python3-certbot-nginx
  # Only lay down the plain-HTTP site when there is no certificate yet. Re-running this to repair
  # something else used to overwrite a working HTTPS site and reload nginx BEFORE calling certbot —
  # one transient certbot failure then left the box permanently downgraded to plain HTTP with a
  # valid certificate sitting unused on disk.
  if [[ -d "/etc/letsencrypt/live/${DOMAIN}" ]]; then
    ok "сертификат для ${DOMAIN} уже есть — конфиг не переписываю, только обновлю"
    certbot renew --quiet --nginx >/dev/null 2>&1 || warn "certbot renew не отработал — проверьте вручную"
    systemctl reload nginx >/dev/null 2>&1 || true
    exit 0
  fi
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
    IP="$(host_ip)"
    CN="$IP"; SAN="IP:${IP}"
  fi
  TLS_DIR=/etc/open-lzt/tls; install -d -m700 "$TLS_DIR"
  # Stable path, generated once: re-running install.sh must not rotate this cert, or every update
  # would blow away the browser exception an operator just clicked through.
  if [[ -f "$TLS_DIR/cert.pem" && -f "$TLS_DIR/key.pem" ]]; then
    ok "self-signed cert already present at $TLS_DIR — kept as-is (delete it to force a new one)"
  else
    openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
      -keyout "$TLS_DIR/key.pem" -out "$TLS_DIR/cert.pem" \
      -subj "/CN=${CN}" -addext "subjectAltName=${SAN}" >/dev/null 2>&1
    chmod 600 "$TLS_DIR/key.pem"
    ok "generated self-signed cert for ${CN}"
  fi
  { if port_taken_by_other 80; then
      warn "порт 80 занят другим процессом — раздаём только https, редирект с http выключен" >&2
    else
      echo "server {"; echo "    listen 80 default_server;"; listen6 "80 default_server"
      echo "    server_name ${CN};"; echo "    return 301 https://\$host\$request_uri;"; echo "}"
    fi
    echo "server {";
    echo "    listen 443 ssl default_server;";
    listen6 "443 ssl default_server";
    echo "    server_name ${CN};";
    echo "    ssl_certificate     ${TLS_DIR}/cert.pem;";
    echo "    ssl_certificate_key ${TLS_DIR}/key.pem;";
    proxy_block;
    echo "}"; } > "$SITE"
  enable_site
  ok "self-signed cert installed for ${CN} — https://${CN} (browsers will warn; it's self-signed)"

else
  die "unknown TLS mode '$MODE' (want letsencrypt|selfsigned|none)"
fi
