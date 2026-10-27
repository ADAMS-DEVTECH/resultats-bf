# RÉSULTATS-BF

Plateforme de consultation de résultats d'examens, résiliente et scalable,
entièrement décrite en code (Vagrant + VirtualBox).
Projet de groupe, Master 1 Informatique, IBAM, Université Joseph Ki Zerbo.

> Groupe 13 (réseau privé n° 5). Membres : OUEDRAOGO Adama, TEGA Paamda Sawratou Lareine, TINDANO Fernand Amed, KABORE Nongdo Valery Ariel.

## Prérequis

- VirtualBox >= 6.1.28
- Vagrant
- Git
- 8 Go de RAM (le socle obligatoire utilise environ 3 Go)
- Boîte `bento/ubuntu-24.04`, version épinglée `202404.26.0` dans le Vagrantfile (la `202404.23.0` de l'Annexe A du sujet n'existe plus)
- Sous Windows : **Git Bash** pour lancer les scripts de `tests/` et `scripts/bascule.sh`

## Démarrage  rapide

```bash
git clone https://github.com/ADAMS-DEVTECH/resultats-bf.git
cd resultats-bf
cp .env.exemple .env      # puis éditer .env (GROUPE, mots de passe)
vagrant up
```

Sous l'invite de commandes Windows, `cp` n'existe pas : utiliser `copy .env.exemple .env` (ou Git Bash). Dans `.env`, `GROUPE` doit être compris entre 1 et 8 ; les mots de passe ne doivent pas contenir d'apostrophe. Ne jamais commiter `.env`. La première construction prend 10 à 20 minutes (téléchargement de la boîte et des paquets).

Test : `curl http://localhost:8080/info`

Extensions : `E1_LB2=1` (lb2 + IP virtuelle .5) et `E2_OBS=1` (Prometheus + Grafana) dans `.env`.

## Paramètres

| Variable   | Défaut | Rôle                              |
|------------|--------|-----------------------------------|
| `GROUPE`   | 1      | Numéro de groupe, 1 à 8           |
| `NB_APP`   | 2      | Nombre de serveurs applicatifs    |

Exemple : mettre `NB_APP=4` dans `.env`, puis `vagrant up`. Garder la même valeur jusqu'au `vagrant destroy`.

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
scripts/        provisionnement par rôle (bdd.sh, replique.sh, app.sh, lb.sh...) et bascule.sh
app/            service HTTP (/resultat, /sante, /info)
config/         modèles de configuration (noeuds.yml est engendré)
tests/          scénarios de validation V1 à V6
docs/           dossier d'architecture, journal de bord
```

## Procédures d'exploitation

- Ajouter un serveur applicatif : changer `NB_APP` dans `.env`, puis `vagrant up` (HAProxy se regénère seul).
- Bascule de la base sur bdd2 : `vagrant halt bdd1`, puis `bash scripts/bascule.sh` (voir `docs/procedure-bascule.md`). Elle est irréversible : seule une reconstruction complète remet la plateforme à l'état initial.
- Scénarios V1 à V6 : voir `tests/` et `docs/PROCEDURE.md`.
- Procédure complète pas à pas : `docs/PROCEDURE.md`.

## Extensions réalisées

- **E1, répartiteur redondant** : lb2 + keepalived, adresse virtuelle `192.168.X.5` (activer avec `E1_LB2=1`). Reprise mesurée à 3,9 s après coupure brutale de lb1.
- **E2, observabilité** : Prometheus + Grafana sur la machine obs (activer avec `E2_OBS=1`). Grafana : `http://192.168.X.41:3000` (utilisateur `admin`, mot de passe `GRAFANA_ADMIN_PASSWORD`), tableau « RESULTATS-BF ». Contrôles : `curl http://192.168.X.41:9090/-/healthy` et `/api/v1/targets` (la page `/targets` n'existe pas dans ce paquet). 768 Mo de mémoire : juste suffisant, 1024 Mo recommandés.

## Limites connues

- Après une bascule, bdd1 n'est pas remise en réplique de bdd2 : la plateforme n'est plus redondante tant qu'on ne la reconstruit pas.
- Le port 8080 de l'hôte n'est lié qu'à lb1 : pendant une panne de lb1, passer par l'adresse virtuelle `192.168.X.5`.
- V3 (montée en charge) est **non concluant** : 97 à 99 % des réponses étaient en erreur lors des essais, le débit affiché ne mesure donc pas le service. Diagnostic par paliers de concurrence : `bash tests/v3-diagnostic.sh`.
- Reconstruction complète mesurée : 1421 s (V5). Les données de test sont reproductibles (graine fixée dans `scripts/bdd.sh`).
- Les mesures faites avec `curl` en boucle sous Windows sont peu denses (environ 1,5 à 2,5 requêtes par seconde).

## Dépannage

Incidents réellement rencontrés pendant le projet, avec leur cause et la correction. X désigne 55 + GROUPE (groupe 5 : réseau 192.168.60.0/24).

### Installation et démarrage (poste Windows)

| Symptôme | Cause | Remède |
|----------|-------|--------|
| `GROUPE doit être compris entre 1 et 8` | Valeur hors plage dans `.env` (VirtualBox n'autorise que 192.168.56.0 à 192.168.63.255) | Mettre un numéro de 1 à 8 dans `GROUPE=` ; modifier `networks.conf` est interdit par le sujet |
| `Vagrant failed to initialize ... cmd.exe ... not found in the %PATH%` | Variable `PATH` Windows sans `C:\Windows\System32` dans ce terminal | Ouvrir une nouvelle invite de commandes ; `where cmd` doit afficher `C:\Windows\System32\cmd.exe` ; sinon ajouter ce dossier au `PATH` et rouvrir le terminal |
| `'cp' n'est pas reconnu` | Commande Linux tapée dans l'invite de commandes Windows | Utiliser `copy .env.exemple .env`, ou Git Bash |
| `vagrant: command not found`, `HTTP 000`, ou un script qui n'affiche rien | Script `.sh` lancé par `bash` depuis l'invite de commandes Windows, où `vagrant` n'est pas visible | Lancer tous les scripts de `tests/` et `scripts/bascule.sh` dans **Git Bash** |
| `The box you're attempting to add has no available version that matches the constraints` | La version `202404.23.0` de l'Annexe A du sujet n'existe plus pour VirtualBox | Le dépôt épingle `202404.26.0` ; la même version pour tous les membres |
| `Could not resolve host: api.cloud.hashicorp.com` pendant le téléchargement de la boîte | DNS du fournisseur d'accès instable sur le PC | Passer les DNS du PC sur 1.1.1.1 et 8.8.8.8, vider le cache (`ipconfig /flushdns`), relancer `vagrant up` (le téléchargement reprend) ; ou copier le dossier de la boîte depuis un autre poste |
| `The box failed to unpack properly ... Truncated tar archive` | Téléchargement de la boîte interrompu (Ctrl+C) | Relancer `vagrant up` ; si cela persiste, `vagrant box remove bento/ubuntu-24.04 --box-version 202404.26.0` puis `vagrant up` |
| Les VM sont très lentes ou ne démarrent pas | Mémoire insuffisante, Hyper-V actif, virtualisation désactivée dans le BIOS | Fermer les applications lourdes, n'activer qu'une extension à la fois, désactiver Hyper-V |

Les messages `Fixed port collision for 22 => 2222` et `The guest additions on this VM do not match the installed version of VirtualBox` sont normaux : ignorez-les.

### Provisionnement des machines

| Symptôme | Cause | Remède |
|----------|-------|--------|
| `Temporary failure resolving 'archive.ubuntu.com'` dans une VM | DNS de la VM défaillant | Corrigé dans `scripts/lib.sh` (DNS 1.1.1.1 et 8.8.8.8) ; rejouer avec `vagrant provision <machine>` |
| `Failed to fetch http://archive.ubuntu.com/... Connection refused` (adresse IPv6) | La VM essaie l'IPv6 avant l'IPv4 | Corrigé dans `scripts/lib.sh` (`Acquire::ForceIPv4`) |
| L'adresse virtuelle `192.168.X.5` n'apparaît sur aucun répartiteur ; le journal de keepalived répète `killall5: usage` | Sous Ubuntu 24.04, `pidof` est un lien vers `killall5`, et la sonde de keepalived échouait à chaque seconde | Sonde remplacée par `systemctl is-active --quiet haproxy` dans `scripts/lb-config.sh` ; puis `vagrant provision lb1 lb2` |
| `vagrant destroy` laisse des machines orphelines | `NB_APP`, `E1_LB2` ou `E2_OBS` différents entre le `vagrant up` et le `vagrant destroy` | Garder les mêmes valeurs dans `.env` pendant toute la vie de la plateforme |

### Service en fonctionnement

| Symptôme | Cause | Remède |
|----------|-------|--------|
| `curl: Could not resolve host: 192.168.X.21` | Le `X` de l'exemple a été tapé tel quel | Remplacer `X` par 55 + GROUPE (groupe 5 : `192.168.60.21`) |
| Le répartiteur répond `503 No server is available to handle this request` | Aucun serveur applicatif n'est jugé sain, généralement parce que la base est indisponible | `curl -i http://192.168.X.21:3000/sante` : un 503 JSON confirme la base en cause ; `vagrant status`, puis `vagrant up bdd1` ou `bash scripts/bascule.sh` |
| `scripts/bascule.sh` refuse de s'exécuter | bdd1 tourne encore (risque de split-brain), ou bdd2 est arrêtée | Arrêter bdd1 avec `vagrant halt bdd1` ; démarrer bdd2 avec `vagrant up bdd2` |
| Après une bascule, la plateforme n'est plus redondante | bdd1 n'est pas remise en réplique de bdd2 | `vagrant destroy -f` puis `vagrant up` pour revenir à l'état initial |
| `/resultat` donne une moyenne différente d'un poste à l'autre | Les 50 000 lignes sont engendrées avec `random()`, donc à chaque reconstruction | Comportement connu ; fixer la graine dans `scripts/bdd.sh` rendrait les données reproductibles |

### Dépôt Git

| Symptôme | Cause | Remède |
|----------|-------|--------|
| `git add` : `pathspec ... did not match any files`, ou un test qui n'affiche rien | Fichier absent, ou vide (0 octet) après une décompression | Chercher les fichiers vides : `find . -type f -size 0 -not -path "./.git/*" -not -path "./.vagrant/*"` ; restaurer avec `git checkout -- <fichier>` |
| `git push` : `Updates were rejected ... fetch first` | Le dépôt distant contient des commits absents en local (par exemple un README créé puis supprimé sur GitHub) | `git pull origin main --allow-unrelated-histories --no-rebase`, puis `git push` ; ne jamais utiliser `--force` |
| `git push` : erreur 403, `Permission ... denied` | Le compte n'est pas encore collaborateur du dépôt | Demander l'invitation au propriétaire et l'accepter |
| `git push` : `src refspec ... does not match any` | Le nom de la branche à pousser n'existe pas en local | Vérifier avec `git branch`, créer la branche voulue, puis `git push -u origin <branche>` |
| Un éditeur (Vim) s'ouvre pendant une fusion | Git demande le message de fusion | Touche Échap, puis `:q!` et Entrée, ou `git commit --no-edit` ; `git config --global core.editor "notepad"` évite le piège |
| Un mot de passe ou `.env` apparaît dans `git status` | `.env` suivi par erreur | Ne pas commiter ; `git rm --cached .env` ; si un secret a déjà été poussé, changer le mot de passe et prévenir l'équipe |

