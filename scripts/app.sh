#!/bin/bash
# Serveur applicatif (sans état)
. /vagrant/scripts/lib.sh
apt_update_une_fois
apt_installer python3 python3-psycopg2 prometheus-node-exporter

install -d /opt/resultats-bf
install -m 644 /vagrant/app/app.py /opt/resultats-bf/app.py

# Secrets : fichier lisible par root seulement, lu par systemd
cat > /etc/resultats-bf.env <<ENVF
DB_HOSTS=${RESEAU}.31,${RESEAU}.32
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
ENVF
chmod 600 /etc/resultats-bf.env

cat > /etc/systemd/system/resultats-bf.service <<UNIT
[Unit]
Description=Service applicatif RESULTATS-BF
After=network-online.target

[Service]
EnvironmentFile=/etc/resultats-bf.env
ExecStart=/usr/bin/python3 /opt/resultats-bf/app.py
User=nobody
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable resultats-bf > /dev/null 2>&1
systemctl restart resultats-bf
echo "app prête sur ${MON_IP}:3000"
