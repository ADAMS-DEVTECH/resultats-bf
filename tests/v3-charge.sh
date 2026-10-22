#!/bin/bash
# V3 : ab -n 2000 -c 50. Lancer une fois avec NB_APP=2, une fois avec NB_APP=4.
URL=${1:-http://localhost:8080}; N=${2:-2000}; C=${3:-50}
CIBLE="$URL/resultat?matricule=BF000123"
FILTRE='Requests per second|Failed requests|Time per request|Non-2xx'
if command -v ab > /dev/null; then
  ab -n "$N" -c "$C" "$CIBLE" | grep -E "$FILTRE"
else
  echo "ab absent de l'hôte : exécution depuis lb1 (à signaler dans le dossier)."
  cd "$(dirname "$0")/.." && vagrant ssh lb1 -c "ab -n $N -c $C 'http://localhost/resultat?matricule=BF000123'" | grep -E "$FILTRE"
fi
