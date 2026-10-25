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
| IP virtuelle absente (E1) | `pidof` est un lien vers `killall5` sur Ubuntu 24.04 : la sonde keepalived échouait chaque seconde, les deux nœuds restaient en panne | Sonde remplacée par `systemctl is-active --quiet haproxy` |

## 4. Résultats obtenus (domaine architecte réseau)

| Exigence | Résultat |
|----------|----------|
| R1 | `vagrant up` réussi du premier coup sur 5 machines ; reconstruction chronométrée (V5) à faire |
| R2 | Empreinte de `haproxy.cfg` identique avant et après deux `vagrant provision` |
| R3 / V1 | 20 appels à `/info` : 10 app1, 10 app2, écart 0 % |
| R4 / V2 | 0 erreur pendant `vagrant halt app1` ; détection de l'arrêt du service en 1,6 s |
| R5 | Ligne insérée sur bdd1 relue sur bdd2 |
| E1 / V6 | Coupure brutale de lb1 : reprise en 3,9 s ; avec `vagrant halt`, aucune requête perdue |

## 5. Ce que nous ferions autrement

- Mesurer avec un outil plus rapide que `curl` lancé en boucle depuis Windows (environ 1,5 à 2,5 requêtes par seconde observées).
- Réduire `advert_int` de keepalived pour gagner une seconde sur la reprise.
- Prévoir un moyen de remettre bdd1 en réplique après une bascule (non réalisé).

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
_Voir les sections 2 à 5._

### 6.3 TINDANO Fernand Amed, ingénieur données
_À compléter._

### 6.4 KABORE Nongdo Valery Ariel, ingénieur essais et observabilité
_À compléter._
