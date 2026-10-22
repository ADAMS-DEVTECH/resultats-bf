#!/bin/bash
# V4 : panne de la base primaire puis bascule chronométrée
cd "$(dirname "$0")/.."
URL=${URL:-http://localhost:8080}
echo "Avant la panne :"; curl -s -w ' -> HTTP %{http_code}\n' "$URL/sante"
t0=$(date +%s.%N)
vagrant halt bdd1
echo "Après arrêt de bdd1 (attendu : 503, pas de page blanche) :"
sleep 5
curl -s -w ' -> HTTP %{http_code}\n' --max-time 5 "$URL/sante"
curl -s -w ' -> HTTP %{http_code}\n' --max-time 5 "$URL/resultat?matricule=BF000123"
echo "Bascule sur bdd2 :"
scripts/bascule.sh
curl -s -w ' -> HTTP %{http_code}\n' "$URL/resultat?matricule=BF000123"
awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "Temps total (halt compris) : %.1f s\n", b-a}'
