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

_À compléter par chacun : tâches réalisées, commits hors domaine (rotation obligatoire), difficultés personnelles._
