#!/bin/bash
set -euo pipefail
umask 077
test -f /etc/letsencrypt/live/47-76-244-254.sslip.io/fullchain.pem
cat > /etc/systemd/system/inverter-certificate-renew.service <<'EOF'
[Unit]
Description=Renew INVERTER HTTPS certificate
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/opt/inverter/certbot/bin/certbot renew --cert-name 47-76-244-254.sslip.io --quiet --deploy-hook "/usr/sbin/nginx -t && /usr/sbin/nginx -s reload"
EOF
# Resolve the existing Nginx binary; BT installations may use a nonstandard path.
NGINX="$(command -v nginx)"
sed -i "s|/usr/sbin/nginx|$NGINX|g" /etc/systemd/system/inverter-certificate-renew.service
cat > /etc/systemd/system/inverter-certificate-renew.timer <<'EOF'
[Unit]
Description=Check INVERTER certificate renewal twice daily
[Timer]
OnCalendar=*-*-* 03,15:00:00
RandomizedDelaySec=1800
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now inverter-certificate-renew.timer
systemctl list-timers inverter-certificate-renew.timer --no-pager
