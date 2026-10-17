# db — schéma et migrations PostGIS

Schéma de la base de référence de l'atlas (PostgreSQL 18 + PostGIS, ADR 0003), géré par des migrations **dbmate** en SQL pur (ADR 0010). Le schéma est le contrat commun entre les pipelines et l'application (ADR 0005).

## Deux bases

| Base | Service | Rôle | Migration |
|---|---|---|---|
| Référence | `db-ref` (port 5432) | Données importées et validées | Depuis `main` seulement : `bash scripts/db-ref-migrate.sh` |
| Développement | `db-dev` (port 5433) | Base jetable pour les branches | Recréée par `bash scripts/db-dev-reset.sh` |

`check.sh` applique les migrations à une base temporaire `atlas_check`, créée dans `db-dev`, y crée les rôles d'essai, lance les tests des invariants du schéma (`pipelines/tests/db`), puis la supprime. Il ne touche jamais la base de référence.

## Schéma

Les migrations traduisent `docs/schema.md`, dans l'ordre des dépendances : extensions, rôles de groupe et types énumérés ; référentiels ; sources ; tronc commun des assertions et tables de type ; événements ; variables, observations et dérivations ; lots et révisions ; triggers et droits. Les écarts relevés en les écrivant sont consignés au §8.5 du schéma.

## Rôles de connexion d'essai

Sur `db-dev` seulement, `scripts/db-dev-roles.sh [base]` crée `atlas_dev_agent` (rôle d'import, contributeur `agent`) et `atlas_dev_reviewer` (rôle de vérification, contributeur `human`), avec les mots de passe de `.env.example`, et enregistre leurs contributeurs dans la base indiquée (par défaut, la base de développement). `scripts/db-dev-reset.sh` et `check.sh` l'appellent. Ces rôles n'existent jamais sur la base de référence (`docs/schema.md`, §5.13).

## Tests des invariants

Chaque invariant du schéma a son test pytest, qui tente de le violer puis montre le cas valide (`pipelines/tests/db`). Hors de `check.sh`, sur une base déjà migrée et dotée des rôles d'essai :

```bash
set -a; source .env.example; set +a
ATLAS_TEST_DB=atlas_dev uv run --directory pipelines pytest -m db
```

Sans `ATLAS_TEST_DB`, ces tests sont ignorés.

Les identifiants sont dans `.env`, une copie de `.env.example` qui n'est jamais versionnée. À défaut de `.env`, les scripts utilisent `.env.example`.

## Commandes

```bash
docker compose up -d --wait db-dev                 # démarrer la base de développement
docker compose run --rm dbmate-dev new <nom>       # créer une migration dans db/migrations
docker compose run --rm dbmate-dev up              # appliquer les migrations à db-dev
docker compose run --rm dbmate-dev status          # état des migrations
bash scripts/db-dev-reset.sh                       # recréer db-dev vide, la migrer, créer les rôles d'essai
bash scripts/db-ref-migrate.sh                     # migrer la base de référence (sur main uniquement)
```

## Règles (CLAUDE.md, règle 6 ; ADR 0010)

- **Immuabilité** : une migration présente sur `main` ne se modifie, ne se renomme et ne se supprime jamais.
- **En avant uniquement** : la section `-- migrate:down` reste vide. Une correction de schéma passe toujours par une nouvelle migration.

`scripts/check-migrations.sh` vérifie ces deux règles, dans `check.sh` comme en CI.
