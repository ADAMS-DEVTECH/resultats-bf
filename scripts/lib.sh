#!/bin/bash
# Fonctions communes (chargé avec : . /vagrant/scripts/lib.sh)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
cd /tmp

# Forcer IPv4 pour apt (évite les échecs sur archive.ubuntu.com en IPv6)
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# DNS public en complément de celui du réseau (évite les échecs de résolution)
install -d /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNS=1.1.1.1 8.8.8.8\n' > /etc/systemd/resolved.conf.d/99-dns.conf
systemctl restart systemd-resolved

apt_update_une_fois() {
  if [ ! -f /var/lib/resultats-bf.apt-update ]; then
    apt-get update -qq
    touch /var/lib/resultats-bf.apt-update
  fi
}

apt_installer() {
  apt-get install -y -qq --no-install-recommends "$@" > /dev/null
}

pg_version() { ls /usr/lib/postgresql | sort -V | tail -n 1; }

psql_pg() { sudo -u postgres psql -v ON_ERROR_STOP=1 -qtA "$@"; }

attendre_pg_local() {
  for _ in $(seq 1 60); do
    sudo -u postgres psql -qtAc "SELECT 1" > /dev/null 2>&1 && return 0
    sleep 1
  done
  echo "PostgreSQL ne répond pas" >&2; return 1
}

# Configuration PostgreSQL commune à bdd1 et bdd2 (idempotente)
pg_configurer() {
  local conf="/etc/postgresql/$(pg_version)/main"
  cat > "$conf/conf.d/resultats-bf.conf" <<CONF
listen_addresses = '*'
wal_level = replica
max_wal_senders = 10
hot_standby = on
wal_keep_size = 256MB
CONF
  if ! grep -q "# resultats-bf" "$conf/pg_hba.conf"; then
    cat >> "$conf/pg_hba.conf" <<HBA
# resultats-bf
host all ${DB_USER} ${RESEAU}.0/24 scram-sha-256
host replication ${REPL_USER} ${RESEAU}.0/24 scram-sha-256
HBA
  fi
}
