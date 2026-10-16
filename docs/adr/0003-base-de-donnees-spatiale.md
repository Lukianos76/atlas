# ADR 0003 — Base de données et extension spatiale

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

Le modèle de données (`docs/modele-donnees.md`) impose :

- des **assertions bitemporelles** : période de validité semi-ouverte, aux bornes éventuellement floues, et historique de révisions qui ne perd rien (P7) ;
- des **géométries versionnées**, sous forme de polygones indépendants, avec des zones floues ;
- un **graphe de filiation** daté, à parcourir pour composer des transferts (§7.2) ;
- des **points de vue** et des **états matérialisés** reproductibles pour un triplet (T, point de vue, R) (§10.4) ;
- des **contraintes structurelles** : au moins une citation par assertion (P3), pas deux préférences actives concurrentes pour un même point de vue (§10.2) ;
- à terme, des **écritures concurrentes** par plusieurs contributeurs.

La cible finale est le monde entier jusqu'au quartier : la **performance est un critère de premier rang**. Les ordres de grandeur ci-dessous sont des estimations à confirmer :

- des centaines de milliers à quelques millions d'unités fines, versionnées sur deux siècles, soit des dizaines de millions de géométries ;
- des observations (unités × millésimes × variables × dimensions) pouvant atteindre des milliards de lignes, chacune assortie d'au moins une citation et d'une révision.

Vérifications faites avec Context7 (octobre 2026), documentation PostGIS :

- `ST_AsMVT` et `ST_TileEnvelope` produisent des tuiles vectorielles directement en SQL. Martin les sert à partir de tables et de fonctions, y compris paramétrées (ADR 0004) ;
- `ST_CoverageSimplify` simplifie un ensemble de polygones voisins en préservant leurs bords communs, sans ouvrir de lacunes.

Vérifications faites avec Context7 (octobre 2026), documentation PostgreSQL 18 :

- `WITHOUT OVERLAPS` s'applique à la dernière colonne d'une clé primaire ou d'une contrainte d'unicité. Cette colonne doit être un intervalle (*range*) ou un multi-intervalle, **jamais vide**. La contrainte équivaut à un `EXCLUDE USING GIST (… WITH =, période WITH &&)`, avec l'extension `btree_gist` pour les colonnes scalaires, mais elle **n'admet pas de clause `WHERE`** ;
- `PERIOD` s'applique à la dernière colonne d'une clé étrangère : les lignes référencées doivent **couvrir entièrement** la période de la ligne qui les référence, et la table cible doit avoir une clé déclarée `WITHOUT OVERLAPS`.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. PostgreSQL + PostGIS** | Une seule base pour tout le modèle. Types d'intervalles et contraintes d'exclusion avec index GiST contre les chevauchements de périodes. CTE récursives pour le graphe de filiation. Vues matérialisées pour les états matérialisés. Contraintes et triggers pour P3 et P7. Génération de tuiles en SQL. Standard très connu | Les dates astronomiques (avant notre ère, bornes floues) ne tiennent pas dans le type `date`. Un serveur à exploiter |
| B. SQLite + SpatiaLite / GeoPackage | Fichier unique, portable, idéal pour distribuer des extraits | Écriture concurrente faible. Pas de contraintes d'exclusion. Peu adapté à une plateforme contributive |
| C. DuckDB + spatial | Excellent en analytique et pour lire des fichiers (Parquet, GeoParquet) | Pas conçu pour des écritures transactionnelles multi-utilisateurs. Pas de serveur de tuiles natif |
| D. Base graphe (Neo4j…) + stockage spatial séparé | Graphe de filiation et relations naturels | Deux bases à synchroniser. Spatial limité. Écosystème cartographique pauvre |

## Décision

On retient **PostgreSQL (version 18 ou plus) avec l'extension PostGIS** comme **source de vérité unique** de l'atlas.

### Échelle du temps

Les dates historiques sont stockées en **jour julien entier** (`int4`), et non avec le type `date`. Le jour julien est un simple compte de jours : il ne dépend d'aucun calendrier. La question du calendrier de normalisation (Q6 du modèle) relève donc de la conversion, pas du stockage. Un `int4` couvre environ ±5,8 millions d'années.

### Dates floues

Une période porte **quatre bornes entières** : début au plus tôt, début au plus tard, fin au plus tôt, fin au plus tard. Une borne ouverte vaut `NULL`.

Deux intervalles en sont **calculés et stockés** (colonnes générées, indexables) :

- le **noyau** `[début au plus tard, fin au plus tôt[`, où le fait est certain ;
- l'**extension maximale** `[début au plus tôt, fin au plus tard[`, où il est possible.

Les contraintes d'exclusion portent sur le **noyau**. Deux états successifs séparés par une transition floue (par exemple l'été 1940) ont des extensions maximales qui se chevauchent légitimement : ce chevauchement est contrôlé comme une anomalie, pas refusé.

### Contraintes temporelles

- `WITHOUT OVERLAPS` et les clés étrangères `PERIOD` de PostgreSQL 18 ne servent que pour des règles **strictes et inconditionnelles**, par exemple dans les tables d'une publication (ADR 0004).
- Les règles **conditionnelles** du modèle (préférences *actives* d'un point de vue, assertions non retirées) utilisent `EXCLUDE … WHERE`, puisque `WITHOUT OVERLAPS` n'accepte ni clause `WHERE` ni intervalle vide, alors que le noyau peut être vide.
- Aucune clé étrangère `PERIOD` n'est posée là où le modèle prévoit une **anomalie** plutôt qu'un refus, par exemple une observation dont la période sort de celle de son entité (§8.3).

### Citations des imports en masse

Pour les imports en masse, la citation n'est pas recopiée ligne par ligne :

- le **lot d'import** porte la citation de l'œuvre importée, avec sa version ou son millésime (§10.5) ;
- chaque observation porte `lot_id NOT NULL` et `localisateur NOT NULL` (ligne ou enregistrement dans le jeu de données) ;
- la révision du lot vaut pour toutes ses observations. Une révision individuelle n'est créée qu'en cas de contestation ou de correction d'une observation.

La règle « pas de donnée sans source » (P3) reste garantie par ces colonnes obligatoires. Le modèle conceptuel ne change pas : la citation d'une observation reste le couple (œuvre du lot, localisateur). Seule sa représentation physique est mutualisée.

## Conséquences

- Les invariants du modèle (citation obligatoire, non-chevauchement des préférences actives, absence de suppression) sont garantis par la base elle-même, indépendamment de l'interface.
- La base exige PostgreSQL 18 ou plus.
- Les conversions entre jours juliens et dates des calendriers d'origine sont des fonctions à écrire et à tester, et chaque conversion reste tracée (§3.1).
- Le volume des imports en masse est réduit d'une ligne de citation et d'une ligne de révision par observation.
- **Volume** : l'indexation (GiST spatial et temporel) et le partitionnement des grandes tables (observations, révisions, citations) sont à concevoir dès le schéma pour le volume mondial, et à valider par le banc d'essai prévu à l'ADR 0006.
- Les tuiles peuvent être produites à partir de la base, en export pour Tippecanoe ou directement par Martin (ADR 0004).
- DuckDB peut servir d'outil dans les pipelines d'import (ADR 0006), mais jamais de base de référence.
- La base doit être sauvegardée et exploitée : son hébergement relève de l'ADR 0007.
