#!/bin/bash
# R5 : une écriture sur bdd1 est visible sur bdd2
cd "$(dirname "$0")/.."
. <(tr -d '\r' < .env)
ID="TEST$(date +%s)"
vagrant ssh bdd1 -c "sudo -u postgres psql -d $DB_NAME -qc \"INSERT INTO resultats VALUES ('$ID','Test repl','A',12.5,true)\"" 2>/dev/null
sleep 1
echo "Lecture sur bdd2 :"
vagrant ssh bdd2 -c "sudo -u postgres psql -d $DB_NAME -tAc \"SELECT matricule, nom FROM resultats WHERE matricule='$ID'\"" 2>/dev/null
vagrant ssh bdd1 -c "sudo -u postgres psql -d $DB_NAME -qc \"DELETE FROM resultats WHERE matricule='$ID'\"" 2>/dev/null
