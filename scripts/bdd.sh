#!/bin/bash
# bdd1 : PostgreSQL primaire
. /vagrant/scripts/lib.sh
apt_update_une_fois
apt_installer postgresql prometheus-node-exporter

PGV=$(pg_version)
pg_configurer
systemctl restart "postgresql@${PGV}-main"
attendre_pg_local

# Rôles (créés une fois, mot de passe réappliqué à chaque fois)
psql_pg -c "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 \
  || psql_pg -c "CREATE ROLE ${DB_USER} LOGIN"
psql_pg -c "ALTER ROLE ${DB_USER} PASSWORD '${DB_PASSWORD}'"
psql_pg -c "SELECT 1 FROM pg_roles WHERE rolname='${REPL_USER}'" | grep -q 1 \
  || psql_pg -c "CREATE ROLE ${REPL_USER} REPLICATION LOGIN"
psql_pg -c "ALTER ROLE ${REPL_USER} PASSWORD '${REPL_PASSWORD}'"

# Base et données
psql_pg -c "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 \
  || psql_pg -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}"

psql_pg -d "${DB_NAME}" <<SQL
CREATE TABLE IF NOT EXISTS resultats (
  matricule text PRIMARY KEY,
  nom       text NOT NULL,
  serie     text NOT NULL,
  moyenne   numeric(4,2) NOT NULL,
  admis     boolean NOT NULL
);
INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
SELECT m, 'Candidat ' || i, (ARRAY['A','C','D','E'])[1 + i % 4], mo, mo >= 10
FROM (SELECT i, 'BF' || lpad(i::text, 6, '0') AS m,
             round((random() * 20)::numeric, 2) AS mo
      FROM generate_series(1, 50000) AS i) t
WHERE NOT EXISTS (SELECT 1 FROM resultats);
GRANT SELECT ON resultats TO ${DB_USER};
ANALYZE resultats;
SQL
echo "bdd1 prête : $(psql_pg -d "${DB_NAME}" -c 'SELECT count(*) FROM resultats') lignes"
