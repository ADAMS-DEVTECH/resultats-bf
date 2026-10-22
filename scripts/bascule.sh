#!/bin/bash
# Procédure de bascule : promeut bdd2 en primaire et chronomètre la reprise.
# Prérequis : bdd1 est arrêtée (vagrant halt bdd1). Lancer depuis la racine du dépôt.
cd "$(dirname "$0")/.."
URL=${URL:-http://localhost:8080}

if vagrant status bdd1 --machine-readable | grep -q ',state,running'; then
  echo "bdd1 tourne encore : arrêtez-la d'abord (risque de split-brain)." >&2
  exit 1
fi

t0=$(date +%s.%N)
EN_RECOVERY=$(vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '\r ')
if [ "$EN_RECOVERY" = "t" ]; then
  vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_promote(wait => true)'" 2>/dev/null
else
  echo "bdd2 est déjà primaire."
fi

# Les apps essaient bdd1 puis bdd2 (DB_HOSTS) : le service revient tout seul.
for _ in $(seq 1 120); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$URL/sante")
  [ "$code" = "200" ] && break
  sleep 0.5
done
t1=$(date +%s.%N)
echo "/sante renvoie $code"
awk -v a="$t0" -v b="$t1" 'BEGIN{printf "Durée de la bascule : %.1f s\n", b-a}'
