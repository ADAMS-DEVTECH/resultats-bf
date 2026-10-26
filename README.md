# RÉSULTATS-BF

Plateforme de consultation de résultats d'examens, résiliente et scalable,
entièrement décrite en code (Vagrant + VirtualBox).
Projet de groupe, Master 1 Informatique, IBAM, Université Joseph Ki Zerbo.

> Groupe : ___  Membres : ___, ___, ___, ___

## Prérequis

- VirtualBox >= 6.1.28
- Vagrant
- Git
- 8 Go de RAM (le socle obligatoire utilise environ 3 Go)
- Boîte `bento/ubuntu-24.04` (version épinglée dans le Vagrantfile)

## Démarrage  rapide

```bash
git clone <url-du-depot> resultats-bf
cd resultats-bf
cp .env.exemple .env      # puis éditer .env (GROUPE, mots de passe)
vagrant up
```

Test : `curl http://localhost:8080/info`

Extensions : `E1_LB2=1` (lb2 + IP virtuelle .5) et `E2_OBS=1` (Prometheus + Grafana) dans `.env`.

## Paramètres

| Variable   | Défaut | Rôle                              |
|------------|--------|-----------------------------------|
| `GROUPE`   | 1      | Numéro de groupe, 1 à 8           |
| `NB_APP`   | 2      | Nombre de serveurs applicatifs    |

Exemple : `NB_APP=4 vagrant up`

## Architecture

| Machine | Rôle                         | IP (X = 55 + GROUPE) |
|---------|------------------------------|----------------------|
| lb1     | Répartiteur HAProxy          | 192.168.X.11         |
| lb2     | Répartiteur passif (E1)      | 192.168.X.12         |
| app1..N | Serveurs applicatifs         | 192.168.X.21..2N     |
| bdd1    | PostgreSQL primaire          | 192.168.X.31         |
| bdd2    | Réplique en flux             | 192.168.X.32         |
| obs     | Prometheus + Grafana (E2)    | 192.168.X.41         |

Seul le répartiteur expose un port vers l'hôte (8080 -> 80).

## Structure du dépôt

```
Vagrantfile     définition des VM (source unique de vérité)
scripts/        provisionnement par rôle + bascule.sh
scripts/        provisionnement par rôle (bdd.sh, replique.sh, app.sh, lb.sh...)
app/            service HTTP (/resultat, /sante, /info)
config/         modèles de configuration (noeuds.yml est engendré)
tests/          scénarios de validation V1 à V6
docs/           dossier d'architecture, journal de bord
```

## Procédures d'exploitation

- Ajouter un serveur applicatif : changer `NB_APP` dans `.env`, puis `vagrant up` (HAProxy se regénère seul).
- Bascule de la base sur bdd2 : `vagrant halt bdd1`, puis `scripts/bascule.sh`.
- Scénarios V1 à V6 : voir `tests/` et `docs/PROCEDURE.md`.
- Procédure complète pas à pas : `docs/PROCEDURE.md`.

## Extensions réalisées

_À compléter (deux au minimum parmi E1 à E4)._

## Limites connues

_À compléter._
