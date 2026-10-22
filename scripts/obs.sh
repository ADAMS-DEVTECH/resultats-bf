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

echo "GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}" > /etc/default/grafana-server
chmod 600 /etc/default/grafana-server

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
echo "Grafana : http://${MON_IP}:3000  (utilisateur admin)"
