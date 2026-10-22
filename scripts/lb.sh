#!/bin/bash
# Répartiteur : installation (la configuration est dans lb-config.sh)
. /vagrant/scripts/lib.sh
apt_update_une_fois
apt_installer haproxy python3-yaml apache2-utils curl prometheus-node-exporter
systemctl enable haproxy > /dev/null 2>&1
