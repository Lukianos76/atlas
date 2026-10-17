# Atlas

Atlas interactif et collaboratif qui raconte le monde par la carte : données démographiques, électorales et frontières historiques, du monde entier au quartier, chaque donnée étant datée, sourcée et rattachée au territoire tel qu'il existait à sa date.

Piliers (détail : `docs/vision.md`) :
- **Espace et temps** : naviguer du monde au quartier, et remonter les décennies et les siècles.
- **Fiabilité** : chaque donnée est neutre, vérifiable et sourcée, à la manière de Wikipédia.
- **Intelligence collective** : une communauté contribue, croise les sources et documente.

Identité visuelle : fonds de carte sombres et épurés ; les données « éclairent » le territoire.

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

Des hooks Claude Code (`.claude/settings.json`) formatent et lintent chaque fichier modifié (Biome sous `apps/web`, Ruff sous `pipelines`), puis vérifient les types (tsc, pyright) des composants modifiés à la fin de chaque réponse. Seules les modifications par Edit ou Write sont vues : `check.sh` reste la vérification qui fait foi.

## Règles non négociables

1. **Aucune donnée sans source.** Toute assertion (nom, code, statut, géométrie, relation, observation) et tout événement portent au moins une citation précise : œuvre et localisateur. Ne jamais inventer, estimer ni compléter une valeur, un code, une date ou un contour qu'aucune source n'affirme. Wikipédia, Wikidata et OpenStreetMap ne sont jamais une source : ils servent à trouver la source d'origine. Si la source manque, s'arrêter et le signaler.
2. **Politique éditoriale.** Territoires disputés, recevabilité des sources, licences, représentations cartographiques et incertitude suivent `docs/politique-editoriale.md`. Les qualifications historiques (création, suppression, type d'événement, niveau de certitude) et les choix éditoriaux (préférence par défaut, point de vue, seuils, couleurs) sont **proposés, jamais appliqués sans ma validation**.
3. **TypeScript strict.** Le mode `strict` reste activé. Ne pas l'assouplir ni le contourner (`any`, `@ts-ignore`, `@ts-expect-error`, assertions `as` forcées) sans justification que j'ai validée.
4. **Vérifications avant de déclarer une tâche terminée.** Sur chaque composant touché : vérification des types (tsc, pyright), lint et formatage (Biome côté front, Ruff côté pipelines), tests (Vitest, Playwright si l'interface change, pytest côté pipelines). Pour un lot d'import : les contrôles obligatoires du modèle (§10.5). Pour une publication de tuiles : les trois contrôles d'export de l'ADR 0004. Une vérification qui échoue ou qui n'a pas été lancée est signalée telle quelle, et la tâche n'est pas terminée.
5. **Langue du code.** Les identifiants sont en anglais, selon le glossaire `docs/glossaire.md`. Un terme du modèle absent du glossaire n'est pas traduit à la volée : sa traduction est proposée pour ajout au glossaire. Commentaires et documentation en français.
6. **Migrations immuables, en avant uniquement, deux bases.** Une migration appliquée ne se modifie jamais ; toute évolution du schéma passe par une nouvelle migration. Les migrations vont en avant uniquement : la section `-- migrate:down` reste vide, et une correction de schéma passe toujours par une nouvelle migration. La **base de référence** (données importées et validées) n'est migrée que depuis `main` (`scripts/db-ref-migrate.sh`) ; les branches n'utilisent que la **base de développement**, jetable, recréée par `scripts/db-dev-reset.sh`. Voir l'ADR 0010.
7. **Rien de lourd ni de secret dans git.** Ni données (fichiers sources, exports, archives de tuiles), ni secrets. Les fichiers de test sont de petits extraits, avec leur source.
8. **Une branche par tâche.** Aucun commit direct sur la branche principale. Chaque commit porte la ligne `Signed-off-by` du DCO (`git commit -s`, ADR 0011).
9. **Séparation des rôles.** Claude Code et les pipelines se connectent à la base de référence avec un rôle d'import : ils insèrent et proposent, ils ne valident jamais un lot ni une assertion. Seul un rôle de vérification, propre à un contributeur humain, passe un lot ou une assertion à `validated`. Ses identifiants, comme ceux du superutilisateur et du propriétaire du schéma, ne figurent jamais dans le `.env` ni dans un fichier lisible par les pipelines ou par Claude Code. Le contributeur enregistré est celui du rôle de connexion (`current_user`), jamais une valeur déclarée. Voir `docs/schema.md` §5.13.

## Pilotage

L'état du projet vit dans `docs/`, pas dans la conversation. Toute session reprend depuis ces fichiers.

| Fichier | Rôle |
|---|---|
| `docs/roadmap.md` | Jalons engagés et tâches cochables, par ordre de priorité. Seule source de « quelle est la prochaine tâche ». |
| `docs/backlog.md` | Réserve non engagée. Une entrée ne passe dans la roadmap qu'avec mon accord. |
| `docs/specs/` | Une spec par fonctionnalité : objectif, critères d'acceptation, hors périmètre (`docs/specs/README.md`). |
| `docs/adr/` | Décisions d'architecture. Un nouvel ADR est créé au statut « proposé ». |
| `docs/data-sources.md` | Registre des jeux de données : source, licence, millésime, granularité, traitement, statut. |

### Méthode

- **Planifier avant d'implémenter.** Aucun code sans un plan que j'ai validé. Le plan signale les décisions qui me reviennent (règle 2).
- **Ne jamais intégrer une donnée sans source** (règle 1). Toute nouvelle source entre d'abord dans `docs/data-sources.md` au statut « envisagée », et je valide son usage.
- **Rien n'est « validé » sans mon accord explicite sur ce contenu.** Par défaut : « proposé ».
- Avant un commit : `bash check.sh` complet sur l'état final, résultat et diff complet présentés ; je donne mon accord explicite, puis `git commit -s`.
- À la fin d'une tâche : cocher la roadmap, mettre à jour la spec et le registre, et proposer un ADR si une décision d'architecture a été prise.

### Commandes et sous-agents

| Quand | Quoi |
|---|---|
| Passer à la tâche suivante | `/next-task` : planifier, attendre ma validation, implémenter, vérifier, relire, mettre à jour la roadmap |
| Nouvelle fonctionnalité | `/new-spec` : m'interroger, rédiger la spec, l'ajouter à la roadmap |
| Faire le point | `/project-status` |
| Découper une tâche en étapes (lecture seule) | sous-agent `planner` |
| Relire un diff avant commit | sous-agent `reviewer`, toujours |
| Un diff touche des données, sources, fixtures, migrations de contenu, textes affichés | sous-agent `data-verifier`, en plus de `reviewer` |

Les sous-agents n'ont ni Edit ni Write et ne lancent pas d'autres sous-agents ; leur Bash est limité à la lecture par leur consigne, pas techniquement. Leurs conclusions me sont rapportées telles quelles, même quand je ne les suis pas.

## Documents de référence

Lire le document concerné **avant** de travailler sur le sujet. Leur contenu n'est pas recopié ici : en cas de doute, le document fait foi. Un écart au modèle ou à un ADR passe par une révision proposée du document, jamais directement par le code.

| Sujet | Document |
|---|---|
| Finalité, public, identité visuelle | `docs/vision.md` |
| Jalons et tâches engagés | `docs/roadmap.md` |
| Spécifications des fonctionnalités | `docs/specs/` |
| Registre des jeux de données | `docs/data-sources.md` |
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
| Tâches identifiées, non engagées | `docs/backlog.md` |
