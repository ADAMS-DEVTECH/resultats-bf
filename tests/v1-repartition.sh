#!/bin/bash
# V1 : 20 appels à /info, répartition entre les serveurs
URL=${1:-http://localhost:8080}
for i in $(seq 1 20); do curl -s "$URL/info"; echo; done \
  | cut -d'"' -f4 | sort | uniq -c | tee /tmp/v1.txt
awk '{n[NR]=$1} END{mx=n[1]; mn=n[1]; for(i in n){if(n[i]>mx)mx=n[i]; if(n[i]<mn)mn=n[i]}
     printf "Serveurs vus : %d ; écart max-min : %.0f %% (objectif < 20 %%)\n", NR, (mx-mn)/20*100}' /tmp/v1.txt
