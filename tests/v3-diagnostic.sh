#!/bin/bash
# Diagnostic de V3 : fait varier la concurrence pour trouver à partir de quand les erreurs apparaissent.
# Usage : bash tests/v3-diagnostic.sh [nombre_de_requetes]   (défaut : 500 par palier)
cd "$(dirname "$0")/.."
. <(tr -d '\r' < .env)
RESEAU="192.168.$((55 + GROUPE))"
N=${1:-500}
printf "%-12s %-12s %-14s\n" "concurrence" "req/s" "non-2xx (%)"
for C in 1 5 10 20 50; do
  if command -v ab > /dev/null; then
    S=$(ab -n "$N" -c "$C" "http://localhost:8080/resultat?matricule=BF000123" 2>&1)
  else
    S=$(vagrant ssh lb1 -c "ab -n $N -c $C 'http://localhost/resultat?matricule=BF000123'" 2>&1)
  fi
  S=$(echo "$S" | tr -d '\r')
  RPS=$(echo "$S" | awk '/Requests per second/{print $4}')
  NON=$(echo "$S" | awk '/Non-2xx responses/{print $3}'); NON=${NON:-0}
  printf "%-12s %-12s %-14s\n" "$C" "${RPS:-?}" "$(awk -v n="$NON" -v t="$N" 'BEGIN{printf "%.1f", 100*n/t}')"
  sleep 5
done
echo
echo "Compteurs HAProxy cumulés (colonnes : proxy, serveur, réponses 2xx, réponses 5xx) :"
curl -s "http://$RESEAU.11:8404/;csv" | cut -d, -f1,2,41,44 | grep -E '^(#|web,|apps,)'
