# db — schéma et migrations PostGIS

Schéma de la base de référence de l'atlas (PostgreSQL 18 + PostGIS, ADR 0003), géré par des migrations **dbmate** en SQL pur (ADR 0010). Le schéma est le contrat commun entre les pipelines et l'application (ADR 0005).

## Deux bases

| Base | Service | Rôle | Migration |
|---|---|---|---|
| Référence | `db-ref` (port 5432) | Données importées et validées | Depuis `main` seulement : `bash scripts/db-ref-migrate.sh` |
| Développement | `db-dev` (port 5433) | Base jetable pour les branches | Recréée par `bash scripts/db-dev-reset.sh` |

`check.sh` applique les migrations à une base temporaire `atlas_check`, créée dans `db-dev` puis supprimée. Il ne touche jamais la base de référence.

Les identifiants sont dans `.env`, une copie de `.env.example` qui n'est jamais versionnée. À défaut de `.env`, les scripts utilisent `.env.example`.

## Commandes

```bash
docker compose up -d --wait db-dev                 # démarrer la base de développement
docker compose run --rm dbmate-dev new <nom>       # créer une migration dans db/migrations
docker compose run --rm dbmate-dev up              # appliquer les migrations à db-dev
docker compose run --rm dbmate-dev status          # état des migrations
bash scripts/db-dev-reset.sh                       # recréer db-dev vide puis la migrer
bash scripts/db-ref-migrate.sh                     # migrer la base de référence (sur main uniquement)
```

## Règles (CLAUDE.md, règle 6 ; ADR 0010)

- **Immuabilité** : une migration présente sur `main` ne se modifie, ne se renomme et ne se supprime jamais.
- **En avant uniquement** : la section `-- migrate:down` reste vide. Une correction de schéma passe toujours par une nouvelle migration.

`scripts/check-migrations.sh` vérifie ces deux règles, dans `check.sh` comme en CI.
