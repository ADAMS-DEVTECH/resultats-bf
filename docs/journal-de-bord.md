# Journal de bord, projet RESULTATS-BF

Groupe 13 (réseau privé n° 5, soit 192.168.60.0/24). Membres : OUEDRAOGO Adama (SIE), TEGA Paamda Sawratou Lareine (SIE), TINDANO Fernand Amed (SI), KABORE Nongdo Valery Ariel (SIE) .

## 1. Répartition des rôles

| Rôle | Membre | Domaine |
|------|--------|---------|
| Architecte réseau et répartition | OUEDRAOGO Adama | Plan d'adressage, Vagrantfile, HAProxy, sonde de santé, E1 |
| Ingénieur applicatif | TEGA Paamda Sawratou Lareine | Service HTTP, absence d'état, gestion des erreurs, E4 |
| Ingénieur données | TINDANO Fernand Amed | PostgreSQL, réplication, bascule, E3 |
| Ingénieur essais et observabilité | KABORE Nongdo Valery Ariel | Scénarios V1 à V6, mesures, E2, rédaction des résultats |

Extensions retenues : E1 (lb2 + IP virtuelle VRRP) et E2 (Prometheus + Grafana).

## 2. Décisions prises et pourquoi

| Date | Décision | Raison |
|------|----------|--------|
| 21/10 | Un seul Vagrantfile qui écrit `config/noeuds.yml`, dont dérivent HAProxy et Prometheus | Source unique de vérité : aucune IP d'app en dur (exigence R3) |
| 21/10 | `NB_APP`, `GROUPE` et les extensions se règlent dans `.env` | Évite d'oublier une variable ponctuelle et garde `vagrant destroy` cohérent |
| 21/10 | Les apps reçoivent `DB_HOSTS=bdd1,bdd2` avec `target_session_attrs=read-write` | Après promotion de bdd2, le service revient sans reconfigurer les apps |
| 21/10 | Configuration du répartiteur régénérée à chaque `vagrant up` (`run: "always"`) | `NB_APP=4 vagrant up` suffit : HAProxy suit tout seul |
| 21/10 | Sonde HAProxy : `inter 1s fall 2`, `option redispatch` | Détection en quelques secondes, rejeu des requêtes en cours |
| 22/10 | Sonde keepalived réécrite avec `systemctl is-active haproxy` | `pidof` échouait sur Ubuntu 24.04 (voir difficultés) |
| 26/10 | E2 : Prometheus, node_exporter et Grafana sur la machine obs ; source de données et tableau de bord fournis par le dépôt | Voir le débit monter pendant la charge et une machine disparaître pendant la panne |
| 26/10 | Graine fixe dans `scripts/bdd.sh` (`SELECT setseed(0.42);`, commit `2bd83e4`) | Données identiques à chaque reconstruction : mesures reproductibles d'un poste à l'autre |
| 27/10 | `tests/v3-charge.sh` signale une mesure non valide ; ajout de `tests/v3-diagnostic.sh` | V3 donnait 97 à 99 % de réponses en erreur : le débit affiché ne mesurait pas le service |

## 3. Difficultés rencontrées et solutions

| Difficulté | Cause | Solution |
|------------|-------|----------|
| `vagrant up` : version de boîte introuvable | `202404.23.0` (Annexe A du sujet) n'existe plus pour VirtualBox | Version épinglée remplacée par `202404.26.0`, identique pour tous les membres |
| `GROUPE doit être compris entre 1 et 8` | Le groupe 13 dépasse la plage 192.168.56.0/21 de VirtualBox | Réseau n° 5 utilisé (13 − 8) ; modifier `networks.conf` est interdit par le sujet |
| Téléchargement de la boîte : `Could not resolve host` | DNS du fournisseur d'accès instable sur le PC | Nouvelle tentative après changement de DNS ; la boîte peut aussi se copier depuis un autre poste |
| `apt` : échecs de connexion sur archive.ubuntu.com | La VM essayait l'IPv6 d'abord | `Acquire::ForceIPv4` ajouté dans `scripts/lib.sh` |
| `Temporary failure resolving 'archive.ubuntu.com'` dans lb1 | DNS de la VM défaillant | DNS publics 1.1.1.1 et 8.8.8.8 ajoutés dans `lib.sh` ; `apt-get update` avant l'installation de keepalived |
| `tests/r5-replication.sh` n'affichait rien | Fichier vide (0 octet) après la décompression | Fichier recréé ; vérification des fichiers vides avant chaque commit (`find . -size 0`) |
| Push GitHub refusé (`fetch first`) | Le dépôt distant contenait déjà deux commits (README créé puis supprimé) | `git pull --allow-unrelated-histories --no-rebase`, puis push, sans `--force` |
| Grafana plantait en boucle (`read-only file system` sur sa base SQLite) | Notre script d'installation écrasait `/etc/default/grafana-server` avec une seule variable : les chemins de données du paquet disparaissaient | Fichier recréé avec toutes les valeurs d'origine ; mot de passe transmis par un fichier systemd à droits 600 ; le script attend maintenant que Grafana réponde |
| Le provisionnement d'obs s'arrêtait sur « Grafana ne répond pas » alors que le service démarrait | Premier démarrage lent (téléchargement de plugins, 1 processeur, 768 Mo) | Attente portée à 5 minutes et préinstallation des plugins désactivée (à valider à la prochaine reconstruction) |
| `404 page not found` sur `http://192.168.60.41:9090/targets` | Interface web absente de ce paquet Prometheus | Contrôle par l'API : `/-/healthy` et `/api/v1/targets` (7 cibles `up`) |
| V3 : 97 à 99 % de réponses non 2xx | Plateforme saturée (cause probable : connexion à la base par requête sur un seul processeur) ; non confirmée | Mesures déclarées non valides ; diagnostic par paliers de concurrence à refaire (`tests/v3-diagnostic.sh`) |
| IP virtuelle absente (E1) | `pidof` est un lien vers `killall5` sur Ubuntu 24.04 : la sonde keepalived échouait chaque seconde, les deux nœuds restaient en panne | Sonde remplacée par `systemctl is-active --quiet haproxy` |

## 4. Résultats obtenus

| Exigence | Résultat |
|----------|----------|
| R1 | `vagrant up` réussi du premier coup sur 5 machines ; reconstruction chronométrée (V5) : 1421 s (23 min 41 s) |
| R2 | Empreinte de `haproxy.cfg` identique avant et après deux `vagrant provision` |
| R3 / V1 | 20 appels à `/info` : 10 app1, 10 app2, écart 0 % |
| R4 / V2 | 0 erreur pendant `vagrant halt app1` ; détection de l'arrêt du service en 1,6 s |
| R5 | Ligne insérée sur bdd1 relue sur bdd2 |
| E1 / V6 | Coupure brutale de lb1 : reprise en 3,9 s ; avec `vagrant halt`, aucune requête perdue |
| V3 | **Non concluant** : 97 à 99 % de réponses non 2xx dans les 7 essais (2 serveurs, 4 serveurs, 4 serveurs avec E2) |
| V4 | Bascule de la base en 24,4 s puis 26,4 s ; 503 propre à l'arrêt de bdd1 |
| V5 | Reconstruction complète en 1421 s ; `BF000123` vaut 16,38 après la correction de la graine |
| E2 | 7 cibles Prometheus `up`, Grafana répond (200), tableau de bord montrant la charge et la panne d'app1 |

## 5. Ce que nous ferions autrement

- Mesurer avec un outil plus rapide que `curl` lancé en boucle depuis Windows (environ 1,5 à 2,5 requêtes par seconde observées).
- Réduire `advert_int` de keepalived pour gagner une seconde sur la reprise.
- Prévoir un moyen de remettre bdd1 en réplique après une bascule (non réalisé).
- Refaire V3 après diagnostic de la saturation, et ajouter un pool de connexions dans l'application.
- Tester les scripts d'installation d'extensions (E2) dès leur écriture sur une machine réelle : deux défauts de notre script Grafana ont été découverts à l'exécution.

## 6. Contributions de chaque membre

_Chaque membre complète sa partie : tâches réalisées, commit hors domaine (rotation obligatoire), difficultés personnelles._

### 6.1 TEGA Paamda Sawratou Lareine, ingénieur applicatif

**Tâches réalisées**
- Installation sur son propre poste Windows : clone du dépôt, fichier `.env` personnel (`GROUPE=5`), `vagrant up` réussi (5 machines, réseau 192.168.60.0/24), puis vérification via le répartiteur (`/info` alterne app1 et app2, `/resultat` renvoie le candidat). C'est le premier test de reproductibilité réussi par un membre autre que l'architecte.
- Tests de l'application T1 à T7 (rapport `docs/tests-application.md` et `.pdf`, avec captures) : 400 sans matricule, 404 pour un matricule ou une route inconnus, 200 pour un matricule valide ; redémarrage d'app1 testé directement sur son port 3000 (réponse immédiate : le serveur ne garde aucun état) ; base arrêtée : `/sante` répond 503 en JSON, `/info` reste à 200 ; aucun vrai mot de passe dans l'historique Git.
- Mesure : avec la base arrêtée, `/sante` met 2,06 s à répondre 503, ce qui correspond au délai de connexion de 2 s de l'application. Mesure unique, à répéter avant le dossier final.
- Pull request n° 1 (commit `19e2710`) relue et fusionnée dans `main` par ADAMS-DEVTECH.

**Commit hors domaine (rotation)** : branche `fix/bascule-garde-fous`, commit `7464f03`, pull request n° 2. Relecture de `scripts/bascule.sh` (fichier de l'ingénieur données) et ajout de deux garde-fous : le script refuse de s'exécuter si bdd2 est arrêtée, et il se termine en erreur si `/sante` ne revient pas à 200 après 60 s (au lieu d'afficher une durée comme si la bascule avait réussi). Contrôles faits : bdd2 arrêtée, le message « bdd2 n'est pas démarrée : impossible de basculer. » s'affiche ; syntaxe vérifiée avec `bash -n`. Le second garde-fou n'a pas été exercé en conditions réelles : il sera à valider pendant le scénario V4 par l'ingénieur données. Au moment de la rédaction, la pull request est en attente de relecture.

**Difficultés rencontrées**

| Difficulté | Cause | Solution |
|------------|-------|----------|
| Vagrant refusait de démarrer : `cmd.exe` introuvable dans le `PATH` | `PATH` Windows incomplet dans le terminal utilisé | Relance depuis une invite de commandes Windows ; le `vagrant up` a ensuite abouti |
| `git push` refusé : erreur 403, permission refusée | Compte pas encore ajouté comme collaborateur du dépôt | Ajout comme collaboratrice par l'architecte ; le push suivant a réussi |
| `git add docs/tests-application.md` : `pathspec did not match any files` | Le fichier n'était pas encore copié dans `docs/` | Fichiers placés dans `docs/` puis `git add` du rapport, du PDF et du dossier `captures` |
| `curl: Could not resolve host: 192.168.X.21` | Le `X` de l'exemple avait été tapé tel quel | Remplacé par 60 (réseau du groupe 5), test refait |
| `vagrant up bdd1` exécuté avant les `curl` du test T6 | Bloc de commandes collé d'un coup | Test refait commande par commande |
| Accents illisibles quand `type scripts\bascule.sh` est lancé dans `cmd` | Page de code de `cmd` différente de l'UTF-8 du fichier | Affichage seulement : le Bloc-notes confirme UTF-8 et fins de ligne LF ; fichier édité avec le Bloc-notes, jamais réécrit d'après l'affichage de `cmd` |

**Constats utiles au groupe**
- Les 50 000 lignes sont engendrées avec `random()` : le matricule `BF000123` a une moyenne de 9,05 chez moi et de 19,73 chez l'architecte. Fixer la graine dans `scripts/bdd.sh` rendrait les résultats reproductibles.
- Le Vagrantfile utilise `"admin"` comme mot de passe Grafana par défaut si `.env` n'en définit pas : valeur faible à supprimer.
- Le dépôt GitHub s'affiche en visibilité publique ; il doit être passé en privé.

**Ce que je ferais autrement** : automatiser les tests d'erreurs dans un script (`tests/`) au lieu de les saisir à la main, et répéter chaque mesure plusieurs fois.

### 6.2 OUEDRAOGO Adama, architecte réseau et répartition


**Tâches réalisées** : plan d'adressage, Vagrantfile (source unique `noeuds.yml`, lecture de `.env`), HAProxy et sonde de santé, extension E1 (lb2, keepalived, adresse virtuelle). Scénarios V1 (écart 0 %), V2 (0 requête perdue, détection en 1,6 s) et V6 (reprise en 3,9 s). Création et administration du dépôt GitHub, relecture et fusion des pull requests.

**Tâches du rôle « essais et observabilité » réalisées par Adama** (voir 6.4).

**Commit hors domaine** : commit `2bd83e4` sur `scripts/bdd.sh` (fichier de l'ingénieur données) : `SELECT setseed(0.42);` pour rendre les données reproductibles.

**Difficultés** : voir les sections 3 et 4. Une limite de ma méthode : plusieurs scripts que j'avais écrits n'avaient pas été exécutés dans une vraie machine avant d'être donnés aux membres (sonde keepalived, installation de Grafana) ; deux défauts ont été découverts ainsi, puis corrigés.

### 6.3 TINDANO Fernand Amed, ingénieur données

**Tâches réalisées**
- Installation sur son propre poste Windows : clone du dépôt, fichier `.env` personnel (`GROUPE=5`), `vagrant up` réussi (5 machines), puis vérification via le répartiteur.
- Contrôles de la base et de la réplication : 50 000 lignes sur bdd1 ; bdd2 en recovery (`pg_is_in_recovery()` = `t`) ; bdd1 voit sa réplique en état `streaming`.
- Idempotence des scripts de données : après `vagrant provision bdd1 bdd2`, le bloc `pg_hba` n'apparaît qu'une fois et la table contient toujours 50 000 lignes.
- Scénario V4 (panne de la base primaire) réalisé deux fois, la seconde après `vagrant destroy -f` puis `vagrant up` : 503 propre à l'arrêt de bdd1, bascule en **24,4 s** puis **26,4 s** (temps total, arrêt de bdd1 compris : 72,4 s et 73,2 s). Après la bascule, bdd2 n'est plus en recovery et accepte les écritures (`INSERT 0 1`, `DELETE 1`).
- Rédaction de `docs/procedure-bascule.md` : procédure pas à pas, résultats, limites.

**Commit hors domaine (rotation)** : _à compléter (branche, numéro de commit, fichier modifié)_.

**Difficultés rencontrées**

| Difficulté | Cause | Solution |
|------------|-------|----------|
| `vagrant up` : `The box failed to unpack properly` (`Truncated tar archive`) | Téléchargement de la boîte interrompu avec Ctrl+C | `vagrant up` relancé : le téléchargement a repris et abouti |
| `'cp' n'est pas reconnu` | Commande Linux tapée dans l'invite de commandes Windows | `copy .env.exemple .env`, ou Git Bash |
| `git switch -c feat/bascule-v4` : `a branch named ... already exists` | La branche existait déjà sur le poste | `git switch feat/bascule-v4` |
| `vagrant: command not found`, `HTTP 000` et « bdd2 n'est pas démarrée » pendant `tests/v4-panne-bdd.sh` | Script lancé par `bash` depuis l'invite de commandes Windows, où `vagrant` n'est pas visible | Scripts relancés dans Git Bash ; les essais faits depuis `cmd` ne sont pas retenus comme mesures |
| `tests/r5-replication.sh` n'affichait rien après « Lecture sur bdd2 : » | Même cause (lancé depuis `cmd`) | À refaire dans Git Bash (la réplication elle-même est confirmée par `streaming`) |

**Constats utiles au groupe**
- La bascule dure 24 à 26 s, bien plus que les quelques secondes de détection d'un serveur applicatif : la part due à `vagrant ssh` (lent sous Windows), à la promotion et au rétablissement des sondes HAProxy reste à chronométrer.
- Après la bascule, bdd1 n'est pas remise en réplique : la plateforme n'est plus redondante tant qu'on ne la reconstruit pas.
- Les données changent à chaque reconstruction : `BF000123` vaut 15,41 puis 15,09 sur le même poste (graine aléatoire non fixée).

**Ce que je ferais autrement** : décomposer la durée de la bascule étape par étape, automatiser la remise en réplique de l'ancienne primaire et répéter les mesures trois fois.

### 6.4 KABORE Nongdo Valery Ariel, ingénieur essais et observabilité

Les tâches de ce rôle ont été réalisées par Adama : V3, V5, extension E2 et consolidation des résultats (`docs/modele-resultats.md`). _À compléter par le titulaire du rôle : sa part de travail, son commit hors domaine et ses difficultés._
=======
_Voir les sections 2 à 5._




