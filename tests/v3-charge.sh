#!/bin/bash
# V3 : ab -n 2000 -c 50. Lancer avec NB_APP=2, puis avec NB_APP=4 (3 essais chacun).
# Le script signale une mesure NON VALIDE si plus de 1 % des réponses ne sont pas des 2xx.
cd "$(dirname "$0")/.."
URL=${1:-http://localhost:8080}; N=${2:-2000}; C=${3:-50}
if command -v ab > /dev/null; then
  SORTIE=$(ab -n "$N" -c "$C" "$URL/resultat?matricule=BF000123" 2>&1)
else
  echo "ab absent de l'hôte : exécution depuis lb1 (à signaler dans le dossier)."
  SORTIE=$(vagrant ssh lb1 -c "ab -n $N -c $C 'http://localhost/resultat?matricule=BF000123'" 2>&1)
fi
SORTIE=$(echo "$SORTIE" | tr -d '\r')
echo "$SORTIE" | grep -E 'Requests per second|Failed requests|Non-2xx|Time per request'
NON=$(echo "$SORTIE" | awk '/Non-2xx responses/{print $3}'); NON=${NON:-0}
awk -v n="$NON" -v t="$N" 'BEGIN{p=100*n/t; printf "Réponses non 2xx : %d sur %d (%.1f %%)\n", n, t, p;
  if (p>1) print "ATTENTION : mesure NON VALIDE (plus de 1 % de réponses en erreur) : ce débit ne mesure pas le service. Lancer tests/v3-diagnostic.sh."}'
