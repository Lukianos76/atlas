# ADR 0002 — Couche de visualisation de données

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

L'identité visuelle de l'atlas repose sur des données qui « éclairent » un fond sombre : flux (migrations, échanges), densités, effets additifs où les superpositions s'additionnent en lumière (`docs/vision.md`).

Les observations du modèle (`docs/modele-donnees.md`, §8.3) couvrent :

- des indicateurs par entité (population, taux) ;
- des résultats électoraux ventilés par dimensions ;
- des flux entre une entité d'origine et une entité de destination.

La couche de visualisation doit fonctionner au-dessus de MapLibre GL JS (ADR 0001), en globe comme en Mercator, permettre l'animation dans le temps et rester performante à l'échelle mondiale.

Vérifications faites avec Context7 (octobre 2026) :

- `MapLibreOverlay` de deck.gl 9.3 fonctionne en mode intercalé (*interleaved*) avec MapLibre 4.5.1 ou plus, en projection Mercator ou globe ;
- l'option `beforeId` place une couche deck.gl sous une couche MapLibre donnée, par exemple sous les libellés ;
- le blending additif se règle par couche avec `parameters` (par exemple `blendColorSrcFactor: 'src-alpha'`, `blendColorDstFactor: 'one'`), selon les constantes de luma.gl v9 ;
- deck.gl prend en charge WebGPU en plus de WebGL.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. Hybride : couches natives MapLibre + deck.gl intercalé** | Les aplats par entité restent des couches MapLibre, servies par les mêmes tuiles. Les flux (ArcLayer, TripsLayer), les densités (HeatmapLayer, agrégations GPU) et les lueurs passent par deck.gl, en additif couche par couche. Les libellés restent au-dessus des données | Deux moteurs à connaître. Bundle plus lourd. Le support du globe varie selon les couches deck.gl |
| B. Tout en deck.gl intercalé | Un seul modèle de programmation pour toutes les données | Les aplats perdent les expressions de style MapLibre et le partage des tuiles avec le fond |
| C. Couches natives MapLibre uniquement | Le plus simple : heatmap, cercles flous et lignes intégrés | Aucun vrai mode additif, pas d'arcs ni de flux animés : l'identité visuelle ne serait pas tenue |
| D. Couches personnalisées MapLibre en WebGL ou three.js | Contrôle total des shaders et des lueurs | Lourd à maintenir et barrière d'entrée élevée pour les contributeurs. Primitives géographiques à réécrire |
| E. deck.gl sur un canvas séparé (non intercalé) | Un `mix-blend-mode: screen` en CSS donne un éclairage additif global | Les libellés ne peuvent plus passer au-dessus des données. Synchronisation et sélection au clic moins propres |

## Décision

On retient l'**option hybride** :

- les **aplats par entité** (choroplèthes, contours) sont des couches natives MapLibre ;
- les **symboles proportionnels par entité** (cercles) sont des couches natives MapLibre (`circle`), dont le rayon est joint par `feature-state` ;
- les **flux, densités et effets additifs** sont des couches deck.gl, intégrées par `MapLibreOverlay` en mode intercalé, placées sous les libellés avec `beforeId`, avec un blending additif réglé couche par couche.

**deck.gl n'est pas utilisé dans la tranche 1**, qui affiche la population en **cercles proportionnels** et le taux d'évolution en **aplats** (`docs/modele-donnees.md`, §14.2). Il arrive avec la première vue de flux ou de densité.

## Conséquences

- La tranche 1 ne dépend que de MapLibre : ni le poids de deck.gl, ni la question de sa compatibilité avec le globe ne la concernent.

- Le cas le plus fréquent, à commencer par la tranche 1 (population communale), reste dans le format de style MapLibre, accessible aux contributeurs.
- **Cercles proportionnels** : la surface du cercle est proportionnelle à la valeur (rayon proportionnel à sa racine carrée). L'échelle des rayons est **commune à toutes les dates** d'une publication, comme les seuils de classes (`docs/politique-editoriale.md`, §5.4).
- L'ordre d'affichage des cercles (`circle-sort-key`, propriété de mise en page) n'accepte pas `feature-state` : on ne peut pas dessiner les grands cercles sous les petits à partir des valeurs jointes. Les cercles sont donc **semi-transparents et cerclés d'un contour**, pour que les petits restent visibles sous les grands. **À vérifier par un prototype.**
- L'identité visuelle (additif, flux animés) est tenue sans réécrire de primitives géographiques.
- L'équipe doit connaître deux modèles de rendu ; la frontière entre les deux (aplats d'un côté, flux et densités de l'autre) est à documenter.
- Le poids du bundle augmente : deck.gl est à charger de façon différée quand une vue n'en a pas besoin.
- **À vérifier par un prototype** : la compatibilité de chaque couche deck.gl utilisée, en particulier les couches d'agrégation, avec la projection globe de MapLibre.
