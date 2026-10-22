#!/bin/bash
# V5 : destruction puis reconstruction complète, chronométrée
cd "$(dirname "$0")/.."
t0=$(date +%s)
vagrant destroy -f && vagrant up
t1=$(date +%s)
echo "Durée totale de la reconstruction : $((t1 - t0)) s"
curl -s -w ' -> HTTP %{http_code}\n' http://localhost:8080/info
