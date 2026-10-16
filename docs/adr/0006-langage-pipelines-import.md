# ADR 0006 — Langage des pipelines d'import de données

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

Les pipelines lisent des sources hétérogènes :

- les fichiers du Code officiel géographique de l'INSEE et sa table des mouvements ;
- les tableaux de recensement (CSV, XLSX) ;
- les référentiels géographiques (Shapefile, GeoPackage de l'IGN) ;
- plus tard, des sources historiques et des découpages du monde entier.

Ils doivent ensuite :

- traduire ces sources en entités, assertions, citations, événements et transferts, y compris le regroupement des lignes du COG et le signalement des cas ambigus (`docs/modele-donnees.md`, §7.4) ;
- exécuter les **contrôles obligatoires d'un lot** (§10.5) : codes, complétude, total, variation, recalcul par le graphe de filiation ;
- produire le rapport de validation et l'échantillon à vérifier par un humain ;
- écrire dans PostGIS (ADR 0003) et préparer les exports pour Tippecanoe (ADR 0004).

La **performance est un critère de premier rang** : la cible finale est le monde entier jusqu'au quartier. Les volumes estimés vont jusqu'à des dizaines de millions de géométries et des milliards d'observations. La tranche 1 est petite, mais le choix doit tenir à cette échelle.

Le projet reste **contributif** : les pipelines doivent pouvoir être lus et écrits par des contributeurs extérieurs.

Le calcul se répartit ainsi :

| Poste | Où il s'exécute | Le langage compte-t-il ? |
|---|---|---|
| Lecture des fichiers | Moteurs natifs (Polars, DuckDB, GDAL) | Peu, si on passe par ces moteurs |
| Opérations géométriques | GEOS, dans PostGIS ou via Shapely 2 vectorisé | Non |
| Écriture en base | `COPY` binaire vers PostgreSQL | Peu : le goulot est l'indexation (ADR 0003) |
| Tuiles | Tippecanoe | Non |
| Logique propre (traduction en assertions, composition des transferts, contrôles) | Code du pipeline | **Oui** |

Vérifications faites avec Context7 (octobre 2026) :

- GeoPandas et Pyogrio sont maintenus. Pyogrio lit en masse tous les formats vectoriels de GDAL ;
- l'extension spatiale de DuckDB lit les formats GDAL (`ST_Read`), et son extension `postgres` lit et écrit directement dans PostgreSQL.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. Python pour orchestrer, calcul dans les moteurs natifs** | Écosystème géo et tabulaire le plus riche, adapté aux sources irrégulières. Notebooks pour examiner un lot pendant la vérification humaine. Accessible aux contributeurs « données ». Performance correcte si le calcul passe par Polars, DuckDB ou SQL | Exige une discipline : le chemin le plus facile en Python est souvent le plus lent. Deuxième langage dans le monorepo |
| B. Rust | Performance native partout, parallélisme sûr. Polars, GDAL, calamine (XLSX) et les pilotes PostgreSQL existent | Développement plus lent. Outillage géo moins riche. Pas de notebooks. Barrière d'entrée élevée pour les contributeurs |
| C. Go | Bonne performance, concurrence simple | L'écosystème géo et tabulaire le plus pauvre des options compilées |
| D. TypeScript / Node | Un seul langage dans le repo, types partagés avec le front | La plus faible des options pour le calcul massif. Outillage géo et tabulaire pauvre |
| E. SQL d'abord (ogr2ogr, transformations et contrôles en SQL) | Le moins de pièces mobiles, au plus près des données | La logique d'interprétation, comme le regroupement des mouvements du COG, est pénible en SQL. Tests et rapports moins confortables |

## Décision

Les pipelines sont écrits en **Python**, qui **orchestre**. Le **calcul est délégué aux moteurs natifs** :

- lecture et transformation tabulaire avec Polars ou DuckDB ;
- chargement géographique avec GDAL / ogr2ogr et Pyogrio ;
- opérations géométriques et contrôles d'ensemble en SQL dans PostGIS (GEOS) ;
- écriture en base par `COPY` binaire.

Les tests utilisent pytest. L'environnement est géré par uv.

**Règle** : pas de boucle Python ligne à ligne sur un gros volume. Tout traitement massif passe par un moteur natif. Un point chaud qui resterait trop lent est réécrit en Rust et exposé à Python (PyO3).

## Conséquences

- Les pipelines profitent de l'outillage le plus complet pour lire les sources statistiques et historiques, tout en s'appuyant sur des moteurs natifs pour le volume.
- La règle sur les boucles doit être tenue dans la durée : elle fait partie de la relecture du code des pipelines.
- **Banc d'essai de passage à l'échelle**, à réaliser avant de figer les choix d'implémentation : importer l'historique complet des communes françaises et un découpage mondial fin, puis mesurer les temps de lecture, de traduction, de contrôle et d'écriture. Les résultats valideront aussi l'indexation et le partitionnement prévus à l'ADR 0003.
- Le monorepo (ADR 0005) contient deux écosystèmes, TypeScript et Python. Les types du modèle ne sont pas partagés automatiquement entre pipelines et front ; le schéma de la base reste le contrat commun.
- DuckDB sert d'outil de lecture et d'exploration des sources, jamais de base de référence (ADR 0003).
