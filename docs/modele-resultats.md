# Modèle de présentation des résultats V1 à V6

Pour chaque scénario : commande exacte, résultat brut (copier-coller), mesure, commentaire.
Indiquer aussi la machine hôte (CPU, RAM) et la date.

| Scénario | Commande | Résultat brut | Mesure | Commentaire |
|----------|----------|---------------|--------|-------------|
| V1 | `tests/v1-repartition.sh` | | écart = ... % | |
| V2 | `tests/panne.sh app1 http://localhost:8080/info` | | ... requêtes perdues, ... s | |
| V3 (N=2) | `tests/v3-charge.sh` | | ... req/s | |
| V3 (N=4) | `tests/v3-charge.sh` | | ... req/s | |
| V4 | `tests/v4-panne-bdd.sh` | | bascule = ... s | |
| V5 | `tests/v5-reconstruction.sh` | | ... s | |
| V6 | `tests/panne.sh lb1 http://192.168.X.5/info` | | reprise = ... s | |

Répéter V3 trois fois par configuration et donner la médiane.
Si N=4 n'est pas plus rapide que N=2, l'expliquer (un seul processeur partagé), sans maquiller.
