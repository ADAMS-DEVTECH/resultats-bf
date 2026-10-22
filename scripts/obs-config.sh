#!/bin/bash
# Génère la liste des cibles Prometheus depuis config/noeuds.yml (à chaque up)
. /vagrant/scripts/lib.sh
python3 - > /tmp/prometheus.yml.new <<'PY'
import yaml
noeuds = yaml.safe_load(open("/vagrant/config/noeuds.yml"))
print("global:\n  scrape_interval: 5s\nscrape_configs:\n  - job_name: noeuds\n    static_configs:")
for n in noeuds:
    print("      - targets: ['{}:9100']\n        labels: {{instance: '{}'}}".format(n["ip"], n["nom"]))
PY
if ! cmp -s /tmp/prometheus.yml.new /etc/prometheus/prometheus.yml; then
  install -m 644 /tmp/prometheus.yml.new /etc/prometheus/prometheus.yml
  systemctl restart prometheus
fi
systemctl enable prometheus > /dev/null 2>&1
