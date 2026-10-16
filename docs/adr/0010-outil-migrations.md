# ADR 0010 — Outil et règles de migrations

- **Statut** : accepté
- **Date** : 2026-10-17

## Contexte

Le schéma PostGIS (ADR 0003) est le contrat commun entre les pipelines Python et l'application TypeScript (ADR 0005). Il évolue par migrations. CLAUDE.md (règle 6) pose qu'une migration appliquée ne se modifie jamais.

Contraintes :

- ne dépendre d'aucun des deux écosystèmes : ni ORM Python, ni outil Node ;
- écrire le schéma en **SQL pur**, puisque le modèle repose sur des fonctionnalités propres à PostgreSQL (`EXCLUDE … WHERE`, `WITHOUT OVERLAPS`, colonnes générées, PostGIS) ;
- fonctionner à l'identique en local et en CI.

La base de **référence** contient des données importées et validées (§10.5 du modèle), coûteuses à reconstituer. Le travail sur une branche ne doit jamais y laisser un schéma intermédiaire.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. dbmate** | SQL pur, un fichier par migration, binaire unique lancé par son image Docker, indépendant des deux écosystèmes | Pas de somme de contrôle des migrations appliquées |
| B. Flyway (Community) | SQL pur. `validate` compare les sommes de contrôle et détecte une migration modifiée | Lourd (Java). Périmètre de l'édition Community variable selon l'éditeur |
| C. Sqitch | Scripts `deploy`, `revert` et `verify`, dépendances explicites | Trois fichiers par changement et un plan à tenir à jour |
| D. Alembic | Intégré à Python | Pensé autour de SQLAlchemy. Lie le schéma à l'un des deux écosystèmes |

## Décision

1. **Outil** : dbmate, lancé par son image Docker épinglée (`compose.yaml`, services `dbmate-ref` et `dbmate-dev`). Les migrations sont dans `db/migrations/`, en SQL pur. Le schéma n'est pas exporté (`DBMATE_NO_DUMP_SCHEMA`) : les migrations font foi.
2. **Migrations en avant uniquement.** La section `-- migrate:down` reste vide. Une correction de schéma passe toujours par une nouvelle migration. Un retour arrière sur la base de référence se fait par une migration qui corrige, jamais en rejouant une migration descendante.
3. **Immuabilité** : dbmate ne calcule pas de somme de contrôle. Un garde-fou git, `scripts/check-migrations.sh`, lancé par `check.sh` et en CI, refuse toute modification, tout renommage et toute suppression d'une migration présente sur `main`. Il vérifie aussi que les sections `down` sont vides.
4. **Deux bases** :
   - la **base de référence** (`db-ref`), qui contient les données importées et validées, n'est migrée que depuis `main`, avec un arbre propre et à jour (`scripts/db-ref-migrate.sh`, qui refuse dans tout autre cas) ;
   - la **base de développement** (`db-dev`) est jetable. Elle se recrée et se migre par une seule commande (`scripts/db-dev-reset.sh`). Les branches n'utilisent qu'elle.

## Conséquences

- Une migration erronée déjà présente sur `main` se corrige par une nouvelle migration. L'historique du schéma reste intégralement lisible.
- Aucune migration descendante n'est écrite ni testée. La réversibilité n'est pas une propriété du schéma.
- Une branche peut casser sa base de développement sans risque : elle la recrée.
- La base de référence n'est jamais dans un état de schéma qui n'existe pas sur `main`.
- Si une somme de contrôle par l'outil devenait nécessaire, par exemple avec plusieurs bases de référence, le passage à Flyway serait réexaminé.
