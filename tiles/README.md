# tiles — génération des tuiles vectorielles

Ce dossier accueillera la chaîne de génération des archives de tuiles décrite par l'ADR 0004 :

1. export depuis PostGIS des géométries de la publication : toutes les versions valides sur la période, avec leurs bornes de validité, et la couche de points dérivés ;
2. génération par **Tippecanoe** d'une archive **PMTiles** au format MVT, une archive par période historique ;
3. les **trois contrôles d'export** de l'ADR 0004, dont l'échec bloque la publication.

Les options de Tippecanoe interdites pour les archives d'entités, ainsi que les options obligatoires (`--no-tiny-polygon-reduction`, `-r1` pour les points), sont fixées par l'ADR 0004 : il fait foi.

Les archives produites vont dans `tiles/build/`, **jamais versionné** (CLAUDE.md, règle 7). Une publication réunit l'archive et ses fichiers de valeurs (ADR 0009). Elle est immuable et versionnée sous un identifiant de publication.
