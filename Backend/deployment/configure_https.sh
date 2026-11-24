#!/bin/bash
set -euo pipefail
umask 077
DOMAIN=47-76-244-254.sslip.io
ROOT=/opt/inverter
CONFIG=/www/server/panel/vhost/nginx/inverter.conf
CERT=/etc/letsencrypt/live/$DOMAIN
mkdir -p "$ROOT/acme/.well-known/acme-challenge"
chmod 755 "$ROOT/acme" "$ROOT/acme/.well-known" "$ROOT/acme/.well-known/acme-challenge"
backup="$(mktemp "$ROOT/nginx-previous.XXXXXX")"
if [ -f "$CONFIG" ]; then cp "$CONFIG" "$backup"; fi
cat > "$CONFIG" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location ^~ /.well-known/acme-challenge/ { root $ROOT/acme; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
if [ -f "$CERT/fullchain.pem" ]; then
cat >> "$CONFIG" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate $CERT/fullchain.pem;
    ssl_certificate_key $CERT/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    client_max_body_size 128k;
    access_log off;
    location / {
        proxy_pass http://127.0.0.1:8178;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 65s;
        proxy_connect_timeout 5s;
        proxy_redirect off;
    }
}
EOF
fi
if nginx -t; then
    nginx -s reload
else
    if [ -s "$backup" ]; then cp "$backup" "$CONFIG"; else mv "$CONFIG" "$ROOT/nginx-rejected.conf"; fi
    exit 1
fi
