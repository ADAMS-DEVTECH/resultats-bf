# Workflow Git de l'équipe

## Règles d'or

1. Jamais de secret dans Git. `.env` est ignoré ; seul `.env.exemple` est versionné.
   Un secret commité puis supprimé reste dans l'historique (pénalité de 2 points).
2. Jamais de commit direct sur `main`. Tout passe par une branche et une pull request.
3. `main` doit toujours démarrer : `vagrant destroy -f && vagrant up` doit réussir.
4. Chaque PR est relue par un autre membre que son auteur.
5. Chaque membre fait au moins un commit significatif hors de son propre domaine.

## Branches

Une branche par fonctionnalité, nommée `type/sujet` :

- `feat/lb-haproxy`, `feat/app-service`, `feat/bdd-replication`, `feat/tests-v1-v3`
- `fix/...`, `docs/...`, `chore/...`

## Messages de commit

Format : `type(portée): résumé à l'impératif`

```
feat(lb): génère haproxy.cfg depuis noeuds.yml
fix(bdd): écoute sur 0.0.0.0 au lieu de 127.0.0.1
docs(readme): ajoute la procédure de bascule
```

Types : `feat`, `fix`, `docs`, `chore`, `test`, `refactor`.
Petits commits, un sujet par commit.

## Cycle de travail

```bash
git switch main && git pull
git switch -c feat/ma-fonctionnalite
# ... travail, commits ...
git push -u origin feat/ma-fonctionnalite
# ouvrir une pull request, demander une relecture, fusionner
```

## Test hebdomadaire de reproductibilité

Chaque semaine, un membre différent fait sur son poste :

```bash
git clone <url> test-repro && cd test-repro
cp .env.exemple .env
vagrant up
```

Tout geste manuel découvert est corrigé dans le dépôt, pas dans la VM.

## Répartition des rôles

| Rôle                              | Membre | Domaine principal                      |
|-----------------------------------|--------|----------------------------------------|
| Architecte réseau et répartition  | ___    | Vagrantfile, HAProxy, sonde, E1        |
| Ingénieur applicatif              | ___    | Service HTTP, absence d'état, E4       |
| Ingénieur données                 | ___    | PostgreSQL, réplication, bascule, E3   |
| Ingénieur essais et observabilité | ___    | Scénarios V1-V6, mesures, E2           |
