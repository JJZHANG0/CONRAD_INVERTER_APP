#!/bin/bash
set -euo pipefail
umask 077
PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT=/opt/inverter
mkdir -p "$ROOT"
if [ ! -x "$ROOT/python/bin/python3.12" ]; then
  curl -fL --retry 2 'https://github.com/astral-sh/python-build-standalone/releases/download/20261110/cpython-3.12.16%2B20261110-x86_64-unknown-linux-gnu-install_only.tar.gz' -o "$ROOT/python.tar.gz"
  printf '%s\n' 'c2f87d4b4e8db3abddb0f116c6ccfc503d0cbdbb9ee8faacddad1b679ec12e99  /opt/inverter/python.tar.gz' | sha256sum -c -
  tar -xzf "$ROOT/python.tar.gz" -C "$ROOT"
fi
"$ROOT/python/bin/python3.12" -m venv "$ROOT/venv"
"$ROOT/venv/bin/python" -m pip install --disable-pip-version-check -r "$PACKAGE_DIR/requirements.txt"
id -u inverter >/dev/null 2>&1 || useradd --system --home-dir "$ROOT" --shell /sbin/nologin inverter
mkdir -p "$ROOT/app"
cp -R "$PACKAGE_DIR/soulmark_extension" "$ROOT/app/"
cp "$PACKAGE_DIR/model.env" "$ROOT/model.env"
chmod 600 "$ROOT/model.env"
chmod 755 "$ROOT" "$ROOT/app"
chmod -R a+rX "$ROOT/python" "$ROOT/venv" "$ROOT/app"
cat > /etc/systemd/system/inverter.service <<'EOF'
[Unit]
Description=INVERTER reflection gateway
After=network-online.target
Wants=network-online.target
[Service]
User=inverter
Group=inverter
WorkingDirectory=/opt/inverter/app
EnvironmentFile=/opt/inverter/model.env
Environment=PYTHONDONTWRITEBYTECODE=1
ExecStart=/opt/inverter/venv/bin/python -m uvicorn soulmark_extension.gateway:app --host 127.0.0.1 --port 8178 --proxy-headers --forwarded-allow-ips=127.0.0.1 --no-access-log
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
UMask=0077
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable inverter
systemctl restart inverter
for attempt in $(seq 1 15); do
  if curl -fsS http://127.0.0.1:8178/health/ready >/dev/null; then break; fi
  sleep 1
done
curl -fsS http://127.0.0.1:8178/health/ready
# HTTPS provisioning is separate: accepting a new CA agreement requires authorization.
bash "$PACKAGE_DIR/configure_https.sh"
printf '\nINVERTER service ready; verify public HTTPS before installing the app.\n'
