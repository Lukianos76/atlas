# ADR 0001 — Bibliothèque de rendu cartographique

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

L'atlas raconte le monde par la carte (`docs/vision.md`). Trois contraintes guident le choix de la bibliothèque de rendu :

- **identité visuelle** : des fonds de carte épurés et sombres, sur lesquels les données « éclairent » le territoire (flux, densités, effets additifs) ;
- **navigation** : un passage fluide du monde entier jusqu'au quartier, ce qui suppose des tuiles vectorielles et une vue en globe aux petits zooms ;
- **projet contributif** : une licence ouverte, sans clé d'API ni facturation imposée aux contributeurs.

La cible finale est le monde entier à l'échelle locale : la performance du rendu est un critère de premier rang.

La bibliothèque doit aussi accueillir une couche de visualisation de données par-dessus le fond de carte (ADR 0002).

Vérifications faites avec Context7 (octobre 2026) :

- MapLibre GL JS propose une projection globe native (`map.setProjection({type: 'globe'})`), avec une transition automatique vers Mercator aux grands zooms ;
- ses couches personnalisées (*custom layers*) fonctionnent en globe, grâce aux fonctions de projection injectées dans les shaders ;
- MapLibre lit les tuiles MVT et le nouveau format MLT ;
- deck.gl 9.3 s'intègre à MapLibre (version 4.5.1 ou plus) en mode intercalé, en Mercator comme en globe.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. MapLibre GL JS** | Licence BSD. Globe natif. Le format de style permet un fond sombre sur mesure. Grand écosystème (Martin, PMTiles, Protomaps). Fonctionne avec deck.gl | Pas de mode de fusion additif dans le format de style |
| B. Mapbox GL JS v3 | Très abouti (globe, éclairage, effets) | Licence propriétaire depuis la v2, jeton et facturation à l'usage : incompatible avec un projet ouvert et contributif |
| C. CesiumJS | Vrai globe 3D, terrain, 3D Tiles | Lourd. Pensé pour la 3D plutôt que pour la cartographie thématique en 2D. Mise en forme des tuiles vectorielles limitée |
| D. OpenLayers | Très complet, ouvert, gère bien les projections | Pas de globe. Moins fluide pour des tuiles vectorielles denses et animées |
| E. deck.gl seul (GlobeView + MVTLayer) | Un seul moteur de rendu | Rendu des libellés et du fond de carte bien plus pauvre. Il faudrait recréer une bonne part de ce que fait MapLibre |

## Décision

On retient **MapLibre GL JS** comme bibliothèque de rendu cartographique.

## Conséquences

- Le fond de carte et les aplats thématiques s'écrivent dans le format de style MapLibre, ouvert et documenté.
- Le globe est disponible nativement aux petits zooms, sans bibliothèque supplémentaire.
- Le format de style ne propose pas de blending additif. Les effets lumineux (flux, densités, lueurs) passent par une couche complémentaire, traitée par l'ADR 0002.
- Le choix est cohérent avec l'écosystème retenu pour les tuiles (ADR 0004 : PMTiles, Martin, Protomaps).
- Aucune dépendance à une clé d'API ou à un service commercial n'est introduite par le rendu.
