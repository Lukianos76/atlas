# Atlas

Atlas interactif et collaboratif qui raconte le monde par la carte : données démographiques, électorales et frontières historiques, du monde entier au quartier, chaque donnée étant datée, sourcée et rattachée au territoire tel qu'il existait à sa date. La rigueur d'une encyclopédie, la clarté d'une infographie : sur des fonds de carte épurés et sombres, les données éclairent le territoire (contrastes, fractures, flux, interconnexions).

Piliers (détail dans `docs/vision.md`) :
- **exploration dans l'espace et le temps** : du monde à la commune, en remontant les décennies et les siècles ;
- **fiabilité et transparence** : chaque donnée est neutre, vérifiable et sourcée ;
- **intelligence collective** : une communauté contribue, croise les sources et documente.

## Commandes

Monorepo (ADR 0005). Node 26 (`.node-version`), Python 3.14 (`pipelines/.python-version`). Commandes lancées depuis la racine du repo.

| Usage | Front (`apps/web`, pnpm) | Pipelines (`pipelines/`, uv) |
|---|---|---|
| Installer | `pnpm --dir apps/web install` puis `pnpm --dir apps/web exec playwright install chromium` | `uv sync --directory pipelines` |
| Lancer | `pnpm --dir apps/web dev` | — (aucun pipeline dans le squelette) |
| Vérifier les types | `pnpm --dir apps/web typecheck` (tsc) | `uv run --directory pipelines pyright` |
| Lint et formatage | `pnpm --dir apps/web lint` (Biome ; `format` pour corriger) | `uv run --directory pipelines ruff format .` puis `ruff check .` |
| Tests unitaires | `pnpm --dir apps/web test` (Vitest) | `uv run --directory pipelines pytest` |
| Tests de bout en bout | `pnpm --dir apps/web e2e` (Playwright, sur le build de production) | — |

| Usage | Commande |
|---|---|
| Base de développement : démarrer | `docker compose up -d --wait db-dev` |
| Base de développement : migrer | `docker compose run --rm dbmate-dev up` |
| Base de développement : recréer | `bash scripts/db-dev-reset.sh` |
| Nouvelle migration | `docker compose run --rm dbmate-dev new <nom>` |
| Base de référence : migrer (sur `main` uniquement) | `bash scripts/db-ref-migrate.sh` |
| **Tout vérifier** | `bash check.sh` (ou `--web`, `--pipelines`, `--db`, `--reuse`) |

Un hook Claude Code (`.claude/settings.json`) formate, lint et vérifie les types de chaque fichier modifié : Biome puis tsc sous `apps/web`, Ruff puis pyright sous `pipelines`.

## Règles non négociables

1. **Aucune donnée sans source.** Toute assertion (nom, code, statut, géométrie, relation, observation) et tout événement portent au moins une citation précise : œuvre et localisateur. Ne jamais inventer, estimer ni compléter une valeur, un code, une date ou un contour qu'aucune source n'affirme. Wikipédia, Wikidata et OpenStreetMap ne sont jamais une source : ils servent à trouver la source d'origine. Si la source manque, s'arrêter et le signaler. Tout jeu de données importé a sa fiche au statut `validée` dans `docs/data-sources.md`.
2. **Politique éditoriale.** Territoires disputés, recevabilité des sources, licences, représentations cartographiques et incertitude suivent `docs/politique-editoriale.md`. Les qualifications historiques (création, suppression, type d'événement, niveau de certitude) et les choix éditoriaux (préférence par défaut, point de vue, seuils, couleurs) sont **proposés, jamais appliqués sans ma validation**. Il en va de même des choix d'architecture et des choix de sources de données.
3. **TypeScript strict.** Le mode `strict` reste activé. Ne pas l'assouplir ni le contourner (`any`, `@ts-ignore`, `@ts-expect-error`, assertions `as` forcées) sans justification que j'ai validée.
4. **Vérifications avant de déclarer une tâche terminée.** Sur chaque composant touché : vérification des types (tsc, pyright), lint et formatage (Biome côté front, Ruff côté pipelines), tests (Vitest, Playwright si l'interface change, pytest côté pipelines). Pour un lot d'import : les contrôles obligatoires du modèle (§10.5). Pour une publication de tuiles : les trois contrôles d'export de l'ADR 0004. Une vérification qui échoue ou qui n'a pas été lancée est signalée telle quelle, et la tâche n'est pas terminée.
5. **Langue du code.** Les identifiants sont en anglais, selon le glossaire `docs/glossaire.md`. Un terme du modèle absent du glossaire n'est pas traduit à la volée : sa traduction est proposée pour ajout au glossaire. Commentaires et documentation en français.
6. **Migrations immuables, en avant uniquement, deux bases.** Une migration appliquée ne se modifie jamais ; toute évolution du schéma passe par une nouvelle migration. Les migrations vont en avant uniquement : la section `-- migrate:down` reste vide, et une correction de schéma passe toujours par une nouvelle migration. La **base de référence** (données importées et validées) n'est migrée que depuis `main` (`scripts/db-ref-migrate.sh`) ; les branches n'utilisent que la **base de développement**, jetable, recréée par `scripts/db-dev-reset.sh`. Voir l'ADR 0010.
7. **Rien de lourd ni de secret dans git.** Ni données (fichiers sources, exports, archives de tuiles), ni secrets. Les fichiers de test sont de petits extraits, avec leur source.
8. **Une branche par tâche.** Aucun commit direct sur la branche principale. Chaque commit porte la ligne `Signed-off-by` du DCO (`git commit -s`, ADR 0011).
9. **Séparation des rôles.** Claude Code et les pipelines se connectent à la base de référence avec un rôle d'import : ils insèrent et proposent, ils ne valident jamais un lot ni une assertion. Seul un rôle de vérification, propre à un contributeur humain, passe un lot ou une assertion à `validated`. Ses identifiants, comme ceux du superutilisateur et du propriétaire du schéma, ne figurent jamais dans le `.env` ni dans un fichier lisible par les pipelines ou par Claude Code. Le contributeur enregistré est celui du rôle de connexion (`current_user`), jamais une valeur déclarée. Voir `docs/schema.md` §5.13.

## Méthode de travail

Claude Code tient à la fois le rôle de chef de projet et celui de développeur. Le pilotage vit dans `docs/`, pas dans la conversation : la feuille de route, les specs, les ADR et le registre des sources font foi d'une session à l'autre.

- **Planifier avant d'implémenter.** Aucun code avant mon approbation explicite du plan. Une décision qui surgit en cours de route arrête le travail : elle m'est présentée avec une option recommandée.
- **Une tâche = une spec = une branche.** La priorité est celle de `docs/roadmap.md`. Une tâche sans spec en reçoit une avant d'être menée.
- **Commandes** :
  - `/next-task [Tx.y]` : choisit la tâche, la fait planifier, attend ma validation, implémente, vérifie, fait relire, met à jour la roadmap ;
  - `/new-spec [fonctionnalité]` : m'interroge, rédige la spec et l'inscrit dans la roadmap ;
  - `/project-status` : fait, en cours, bloqué, décisions en attente, prochaines étapes.
- **Décisions d'architecture** : un ADR au statut « proposé » dans `docs/adr/`, accepté par moi seul.
- **Avant tout commit** : résultat de `check.sh` et diff complet présentés ; commit sur mon accord.

## Sous-agents

Définis dans `.claude/agents/`. Ils ne décident rien : ils proposent ou constatent.

| Sous-agent | Quand y faire appel | Droits |
|---|---|---|
| `planner` | Avant toute implémentation : découpe la tâche en étapes, liste les décisions qui me reviennent | Lecture seule, pas de code |
| `reviewer` | Après toute implémentation, avant commit : qualité, conformité à CLAUDE.md et aux ADR, tests manquants | Lecture seule ; Bash limité aux consultations git |
| `data-verifier` | Dès qu'un changement touche des données, des citations ou `docs/data-sources.md` : source, licence, date, fiche du registre, fiabilité, neutralité | Lecture seule, web pour vérifier chez l'éditeur ; avis motivé, jamais une décision |

## Documents de référence

Lire le document concerné **avant** de travailler sur le sujet. Leur contenu n'est pas recopié ici : en cas de doute, le document fait foi. Un écart au modèle ou à un ADR passe par une révision proposée du document, jamais directement par le code.

| Sujet | Document |
|---|---|
| Finalité, public, identité visuelle | `docs/vision.md` |
| Modèle conceptuel : entités, assertions, temps, géométries, événements, observations, points de vue | `docs/modele-donnees.md` |
| Périmètre de la tranche 1 et questions ouvertes | `docs/modele-donnees.md` §14 |
| Traduction des mouvements du COG | `docs/modele-donnees.md` §7.4 |
| Lots d'import et règle d'acceptation | `docs/modele-donnees.md` §10.5 |
| Disputes, sources, licences, sémiologie, incertitude | `docs/politique-editoriale.md` |
| Rendu cartographique (MapLibre 6) | `docs/adr/0001-bibliotheque-rendu-cartographique.md` |
| Aplats, cercles proportionnels, flux et densités (deck.gl) | `docs/adr/0002-couche-visualisation-donnees.md` |
| Schéma PostGIS, jours juliens, bornes floues, contraintes temporelles | `docs/adr/0003-base-de-donnees-spatiale.md` |
| Schéma logique de la tranche 1 : tables, contraintes, révisions, rôles | `docs/schema.md` |
| Tuiles, publications, Tippecanoe, contrôles d'export | `docs/adr/0004-tuiles-vectorielles.md` |
| Organisation du monorepo | `docs/adr/0005-structure-du-repo.md` |
| Pipelines Python et moteurs natifs | `docs/adr/0006-langage-pipelines-import.md` |
| Hébergement | `docs/adr/0007-hebergement.md` |
| Front React, Vite, outillage, curseur temporel | `docs/adr/0008-framework-outillage-front.md` |
| Fichiers de valeurs Parquet et manifeste | `docs/adr/0009-format-fichiers-valeurs.md` |
| Outil et règles de migrations, deux bases | `docs/adr/0010-outil-migrations.md` |
| Licences du code et de la documentation, REUSE, DCO | `docs/adr/0011-licence-du-code.md` |
| Sources de géométries historiques (Bas-Rhin) | `docs/recherches/sources-geometries-historiques.md` |
| Correspondance des termes du modèle en anglais | `docs/glossaire.md` |
| Jalons, tâches et priorités ; tâches non priorisées | `docs/roadmap.md` |
| Spécifications des fonctionnalités | `docs/specs/` (gabarit `_gabarit.md`) |
| Registre des jeux de données : licence, édition, granularité, traitement, statut | `docs/data-sources.md` |
| Nouvel ADR | `docs/adr/_gabarit.md` |
