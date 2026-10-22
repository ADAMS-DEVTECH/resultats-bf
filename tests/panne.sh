#!/bin/bash
# V2 et V6 : arrête une machine pendant une charge légère et mesure l'impact.
# Usage : tests/panne.sh <vm> <url> [duree_s]
#   V2 : tests/panne.sh app1 http://localhost:8080/info
#   V6 : tests/panne.sh lb1  http://192.168.<55+G>.5/info
VM=${1:?machine}; URL=${2:?url}; DUREE=${3:-40}; T_PANNE=5
cd "$(dirname "$0")/.."
LOG=$(mktemp); t0=$(date +%s.%N); fait=0
while :; do
  el=$(awk -v a="$(date +%s.%N)" -v b="$t0" 'BEGIN{print a-b}')
  if [ $fait = 0 ] && awk -v e="$el" -v p=$T_PANNE 'BEGIN{exit !(e>=p)}'; then
    vagrant halt "$VM" > /dev/null 2>&1 &
    fait=1; echo "-> vagrant halt $VM à t=${el}s"
  fi
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$URL"); echo "$el $code" >> "$LOG"
  awk -v e="$el" -v d="$DUREE" 'BEGIN{exit !(e>=d)}' && break
  sleep 0.1
done
wait
awk '{t++; if($2!=200){e++; if(!f)f=$1; l=$1}}
     END{printf "Requêtes : %d ; en erreur : %d ; première erreur t=%.1fs ; dernière erreur t=%.1fs ; période dégradée : %.1f s\n",
         t, e+0, f+0, l+0, (e? l-f : 0)}' "$LOG"
echo "Remise en route de $VM..."; vagrant up "$VM" > /dev/null 2>&1; echo "$VM relancée."
