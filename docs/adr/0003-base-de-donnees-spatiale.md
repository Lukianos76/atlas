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

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. PostgreSQL + PostGIS** | Une seule base pour tout le modèle. Types d'intervalles et contraintes d'exclusion avec index GiST contre les chevauchements de périodes. CTE récursives pour le graphe de filiation. Vues matérialisées pour les états matérialisés. Contraintes et triggers pour P3 et P7. Génération de tuiles en SQL. Standard très connu | Les dates astronomiques (avant notre ère, bornes floues) ne tiennent pas dans le type `date`. Un serveur à exploiter |
| B. SQLite + SpatiaLite / GeoPackage | Fichier unique, portable, idéal pour distribuer des extraits | Écriture concurrente faible. Pas de contraintes d'exclusion. Peu adapté à une plateforme contributive |
| C. DuckDB + spatial | Excellent en analytique et pour lire des fichiers (Parquet, GeoParquet) | Pas conçu pour des écritures transactionnelles multi-utilisateurs. Pas de serveur de tuiles natif |
| D. Base graphe (Neo4j…) + stockage spatial séparé | Graphe de filiation et relations naturels | Deux bases à synchroniser. Spatial limité. Écosystème cartographique pauvre |

## Décision

On retient **PostgreSQL avec l'extension PostGIS** comme **source de vérité unique** de l'atlas.

## Conséquences

- Les invariants du modèle (citation obligatoire, non-chevauchement des préférences actives, absence de suppression) sont garantis par la base elle-même, indépendamment de l'interface.
- **Temps historique** : les dates sont stockées sur une échelle numérique normalisée (proleptique, années astronomiques), avec des intervalles de type `int8range` ou `numrange`, et non avec le type `date`. La représentation exacte (jour julien, année décimale…) est à fixer lors de la conception du schéma.
- **Volume** : l'indexation (GiST spatial et temporel) et le partitionnement des grandes tables (observations, révisions, citations) sont à concevoir dès le schéma pour le volume mondial, et à valider par le banc d'essai prévu à l'ADR 0006.
- Les tuiles peuvent être produites à partir de la base, en export pour Tippecanoe ou directement par Martin (ADR 0004).
- DuckDB peut servir d'outil dans les pipelines d'import (ADR 0006), mais jamais de base de référence.
- La base doit être sauvegardée et exploitée : son hébergement relève de l'ADR 0007.
