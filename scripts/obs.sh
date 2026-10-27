#!/bin/bash
# Extension E2 : Prometheus + Grafana (la config des cibles est dans obs-config.sh)
. /vagrant/scripts/lib.sh
apt_update_une_fois
apt_installer prometheus prometheus-node-exporter apt-transport-https gnupg wget ca-certificates

if [ ! -f /etc/apt/sources.list.d/grafana.list ]; then
  install -d -m 755 /etc/apt/keyrings
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list
  apt-get update -qq
fi
apt_installer grafana

# Valeurs d'origine du paquet Grafana : NE PAS réduire ce fichier à une seule variable,
# sinon le service démarre sans chemins de données (base SQLite en lecture seule).
cat > /etc/default/grafana-server <<DEF
GRAFANA_USER=grafana
GRAFANA_GROUP=grafana
GRAFANA_HOME=/usr/share/grafana
LOG_DIR=/var/log/grafana
DATA_DIR=/var/lib/grafana
MAX_OPEN_FILES=10000
CONF_DIR=/etc/grafana
CONF_FILE=/etc/grafana/grafana.ini
RESTART_ON_UPGRADE=true
PLUGINS_DIR=/var/lib/grafana/plugins
PROVISIONING_CFG_DIR=/etc/grafana/provisioning
PID_FILE_DIR=/var/run/grafana
DEF
# Mot de passe administrateur : fourni par un fichier systemd lisible par root seulement
install -d /etc/systemd/system/grafana-server.service.d
cat > /etc/systemd/system/grafana-server.service.d/mot-de-passe.conf <<DROP
[Service]
Environment="GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}"
# Évite le téléchargement de plugins au premier démarrage (lent et inutile ici)
Environment="GF_PLUGINS_PREINSTALL_DISABLED=true"
DROP
chmod 600 /etc/systemd/system/grafana-server.service.d/mot-de-passe.conf
systemctl daemon-reload
systemctl reset-failed grafana-server 2>/dev/null || true

install -d /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards
cat > /etc/grafana/provisioning/datasources/prometheus.yml <<DS
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
DS
cat > /etc/grafana/provisioning/dashboards/resultats-bf.yml <<DB
apiVersion: 1
providers:
  - name: resultats-bf
    type: file
    options:
      path: /var/lib/grafana/dashboards
DB
install -m 644 /vagrant/config/grafana-dashboard.json /var/lib/grafana/dashboards/resultats-bf.json

systemctl enable grafana-server > /dev/null 2>&1
systemctl restart grafana-server
for _ in $(seq 1 150); do
  wget -q -O /dev/null http://localhost:3000/api/health && break
  sleep 2
done
wget -q -O /dev/null http://localhost:3000/api/health \
  || { echo "Grafana ne répond pas : voir journalctl -u grafana-server" >&2; exit 1; }
echo "Grafana : http://${MON_IP}:3000  (utilisateur admin)"
