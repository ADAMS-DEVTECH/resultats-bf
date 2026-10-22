#!/bin/bash
# bdd2 : réplique en flux de bdd1
. /vagrant/scripts/lib.sh
apt_update_une_fois
apt_installer postgresql prometheus-node-exporter

PGV=$(pg_version)
SERVICE="postgresql@${PGV}-main"
DATA="/var/lib/postgresql/${PGV}/main"
MARQUEUR=/var/lib/resultats-bf.replica-init
pg_configurer

# Initialisation unique : après une bascule, on ne doit JAMAIS ré-écraser bdd2
if [ ! -f "$MARQUEUR" ]; then
  for _ in $(seq 1 60); do
    pg_isready -q -h "${RESEAU}.31" -p 5432 && break
    sleep 2
  done
  systemctl stop "$SERVICE"
  rm -rf "${DATA:?}"/*
  sudo -u postgres pg_basebackup \
    -d "host=${RESEAU}.31 user=${REPL_USER} password=${REPL_PASSWORD}" \
    -D "$DATA" -R -X stream -c fast
  touch "$MARQUEUR"
fi
systemctl restart "$SERVICE"
attendre_pg_local
echo "bdd2 prête (en recovery : $(psql_pg -c 'SELECT pg_is_in_recovery()'))"
