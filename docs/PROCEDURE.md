# Procédure pas à pas : de zéro à la soutenance

Toutes les commandes se tapent depuis la racine du dépôt, dans **Git Bash** (Windows).
Le numéro de groupe est noté G, et X = 55 + G (groupe 4 -> X = 59).

## Étape 0 : poste prêt (une fois par membre)

1. Installer VirtualBox (>= 6.1.28), Vagrant et Git (ce dernier fournit Git Bash).
2. Vérifier : `vagrant --version`, `git --version`.
3. Si possible, installer `ab` sur l'hôte (binaire `ab.exe` du paquet Apache httpd pour Windows, section « Apache Lounge »). Sinon `tests/v3-charge.sh` l'exécute depuis lb1.

## Étape 1 : dépôt et configuration

```bash
git clone <url-du-depot> resultats-bf && cd resultats-bf
cp .env.exemple .env
```
Éditer `.env` : mettre votre `GROUPE`, choisir de vrais mots de passe (sans apostrophe).
Ne jamais faire `git add .env` (il est déjà ignoré). Vérifier avec `git status`.

## Étape 2 : comprendre les pièces

| Fichier | Rôle |
|---------|------|
| `Vagrantfile` | Lit `.env`, construit la liste des machines, écrit `config/noeuds.yml`, lance un script par rôle |
| `config/noeuds.yml` | Source unique de vérité (engendré, non versionné) |
| `scripts/bdd.sh` | PostgreSQL primaire, rôles, 50 000 lignes |
| `scripts/replique.sh` | `pg_basebackup` depuis bdd1 : réplique en flux |
| `scripts/app.sh` | Python + service systemd, secrets dans `/etc/resultats-bf.env` |
| `scripts/lb.sh` + `lb-config.sh` | HAProxy ; la config est regénérée à chaque `vagrant up` depuis `noeuds.yml` |
| `app/app.py` | `/resultat`, `/sante`, `/info` |

L'ordre de démarrage suit l'ordre de déclaration : bdd1, bdd2, apps, lb1.

## Étape 3 : premier démarrage (jalon J1)

```bash
vagrant up
vagrant status
```
Compter 10 à 20 minutes la première fois (téléchargement de la boîte et des paquets).
En cas d'échec sur une machine : `vagrant provision <machine>` après correction.

## Étape 4 : vérifier couche par couche

```bash
# base primaire : 50 000 lignes ?
vagrant ssh bdd1 -c "sudo -u postgres psql -d resultats -tAc 'SELECT count(*) FROM resultats'"
# réplique : en recovery (t) ?
vagrant ssh bdd2 -c "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery()'"
# R5 : écriture sur bdd1 visible sur bdd2
tests/r5-replication.sh
# app directe (sans répartiteur)
curl http://192.168.X.21:3000/info
curl http://192.168.X.21:3000/sante
# via le répartiteur
curl http://localhost:8080/info
curl "http://localhost:8080/resultat?matricule=BF000123"
# état des serveurs vus par HAProxy
curl http://192.168.X.11:8404/
```

## Étape 5 : idempotence (R2)

```bash
vagrant ssh lb1 -c "md5sum /etc/haproxy/haproxy.cfg" ; vagrant provision ; vagrant provision
vagrant ssh lb1 -c "md5sum /etc/haproxy/haproxy.cfg"
```
Les empreintes doivent être identiques, et `vagrant provision` ne doit pas échouer.
Faire de même avec `/etc/postgresql/16/main/pg_hba.conf` sur bdd1 : le bloc `# resultats-bf` doit apparaître une seule fois.

## Étape 6 : scalabilité (R3 et V1)

1. Dans `.env`, passer `NB_APP=4`.
2. `vagrant up` crée app3 et app4 et regénère HAProxy tout seul.
3. `tests/v1-repartition.sh` : les 4 serveurs apparaissent.
4. Garder la même valeur dans `.env` pour `vagrant destroy -f` (une valeur plus petite laisserait des VM orphelines).

Ne mettez pas NB_APP en variable d'environnement ponctuelle : vous oublieriez de la remettre.

## Étape 7 : scénarios de validation (jalons J2, J3, S4)

| Scénario | Commande | À relever |
|----------|----------|-----------|
| V1 | `tests/v1-repartition.sh` | Écart < 20 % |
| V2 | `tests/panne.sh app1 http://localhost:8080/info` | Requêtes perdues, période dégradée |
| V3 | `tests/v3-charge.sh` avec NB_APP=2 puis 4 (3 essais chacun) | Requêtes par seconde |
| V4 | `tests/v4-panne-bdd.sh` | 503 propre, durée de bascule |
| V5 | `tests/v5-reconstruction.sh` | Durée totale |
| V6 (E1) | `tests/panne.sh lb1 http://192.168.X.5/info` | Temps de reprise VRRP |

Après V4, bdd1 est arrêtée et bdd2 est primaire. Pour repartir d'un état sain : `vagrant destroy -f && vagrant up`.
Collez les résultats bruts dans `docs/modele-resultats.md`.

## Étape 8 : extensions (au moins deux)

**E1, répartiteur redondant** : mettre `E1_LB2=1` dans `.env`, puis `vagrant up` (crée lb2, configure keepalived sur lb1 et lb2).
L'adresse virtuelle est `192.168.X.5`. Test : `curl http://192.168.X.5/info`, puis V6.
Le port 8080 de l'hôte reste lié à lb1 seulement : pour la démonstration E1, utiliser l'IP virtuelle.

**E2, observabilité** : mettre `E2_OBS=1`, puis `vagrant up` (crée obs, installe Prometheus et Grafana : télécharge environ 300 Mo).
Grafana : `http://192.168.X.41:3000` (admin / mot de passe du `.env`), tableau « RESULTATS-BF ».
Pendant V3 le débit réseau de lb1 monte, pendant V2 la courbe `up` d'app1 tombe à 0.
Mémoire : n'allumez E2 que quand le reste est stable (socle 3,1 Go + lb2 0,5 Go + obs 0,8 Go).

**E3 (Redis) et E4 (déploiement sans coupure)** ne sont pas fournis. Si vous visez l'un d'eux à la place de E1/E2, demandez-moi le script.

## Étape 9 : rendus

- README testé par un camarade : clone, `cp .env.exemple .env`, `vagrant up`, sans aucune question.
- Dossier de 10 à 15 pages : suivre `docs/plan-dossier.md`.
- Journal de bord : `docs/journal-de-bord.md`.
- Vérifier l'historique : `git log --oneline` (4 auteurs) et `git log -p | grep -i password` ne doit montrer aucun vrai mot de passe.
- Répétition de la démo : `tests/v5-reconstruction.sh` sur un poste vierge, puis 3 scénarios.

## Dépannage

| Symptôme | Cause probable | Remède |
|----------|----------------|--------|
| `bad interpreter` / `\r` dans un script | Fins de ligne CRLF | `.gitattributes` présent ? `git add --renormalize .` |
| Service injoignable depuis une autre VM | Écoute sur 127.0.0.1 | Vérifier `0.0.0.0` / `listen_addresses` |
| `vagrant up` : plage d'adresses refusée | Mauvais GROUPE ou `networks.conf` modifié | `GROUPE` entre 1 et 8 |
| bdd2 : `pg_basebackup` échoue | bdd1 pas prête, mauvais mot de passe de réplication | Relire `.env`, puis supprimer `/var/lib/resultats-bf.replica-init` et `vagrant provision bdd2` |
| HAProxy renvoie 503 | Aucune app saine | `curl http://192.168.X.21:3000/sante` ; regarder `systemctl status resultats-bf` |
| Les VM sont lentes | RAM insuffisante, Hyper-V actif | Fermer les extensions, désactiver Hyper-V |
| `vagrant destroy` oublie des VM | NB_APP différent de celui du `up` | Remettre la même valeur dans `.env` |
