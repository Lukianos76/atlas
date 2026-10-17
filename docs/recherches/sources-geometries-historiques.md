# Sources de contours communaux historiques — Bas-Rhin depuis 1968

> **Date de la recherche** : octobre 2026.
> **Objet** : savoir s'il existe des contours communaux du Bas-Rhin pour chaque date de recensement depuis 1968, afin de décider sur quelle géographie se fait la première carte de la tranche 1.
> **Méthode** : recherche web et lecture des fiches des producteurs. Les points non vérifiés sont signalés comme tels.

---

## 1. Décision

**La première carte de la tranche 1 utilise la géographie courante** : les contours d'ADMIN EXPRESS (IGN, édition récente) et les séries de l'INSEE en géographie courante. Ces séries sont importées comme **dérivations externes** et contrôlées par le recalcul via le graphe de filiation (`docs/modele-donnees.md`, §8.4 et Q13).

L'interface indique clairement que les valeurs passées portent sur le **territoire des communes actuelles**.

La population s'y affiche en **cercles proportionnels**, placés sur un point dérivé du contour de chaque commune ; le taux d'évolution annuel moyen s'affiche en choroplèthe (`docs/modele-donnees.md`, §14.2 ; ADR 0002 et 0004).

**Justification.** Le modèle sépare l'histoire des géométries de celle des données. Les observations originales restent rattachées aux communes de chaque époque, avec ou sans géométrie. La tranche 1 teste la seconde, l'histoire des données (entités, mouvements du COG, filiation, dérivations), sur des sources officielles et ouvertes. Aucune source de ce type ne fournit les contours historiques (§3 ci-dessous). Les géométries historiques sont donc reportées, sans bloquer le test du modèle.

Pistes reportées : voir `docs/roadmap.md`.

---

## 2. Sources trouvées

| Source | Couverture | Dates | Licence | Précision |
|---|---|---|---|---|
| **IGN ADMIN EXPRESS** | France entière, communes en vigueur. La couche des communes associées ou déléguées existe au moins depuis la version 3.0 (mai 2021) | Une édition par an depuis 2017 | Licence Ouverte Etalab (toutes les données publiques de l'IGN depuis 2021) | Pas de chiffre officiel trouvé. data.gouv.fr indique que la précision « a changé au fil du temps », notamment avec la version 3. Une ancienne fiche de métadonnées parle de géométrie BD CARTO ; data.gouv.fr rattache ces limites au Référentiel à grande échelle de l'IGN. À lire dans le descriptif de l'édition utilisée |
| **IGN GEOFLA** | France entière, communes en vigueur à chaque édition | 1997, 2002, puis de 2010 à 2016 (data.gouv.fr ne dit pas si c'était chaque année) ; production arrêtée, remplacée par ADMIN EXPRESS | Licence Ouverte 1.0 | Faible : généralisée à partir de la BD CARTO, jusqu'à 1 000 m d'écart avec celle-ci, pour des échelles voisines du 1:1 000 000. Seule la dernière édition est téléchargeable ; aucun accès trouvé aux éditions 1997 et 2002 |
| **Cadastre** (PCI vecteur, export Etalab) | Toutes les communes en PCI vecteur depuis le 1er septembre 2025 | État courant uniquement | Licence Ouverte | Cadastrale, donc fine, mais le cadastre ne fait pas foi pour les limites |
| **Projet COMMUNES** (ANR COMMUNE-HISDBD ; Litvine, Séguy, Thévenin ; CAMPOP, INED, ThéMA), « French Historical GIS » | Toutes les communes de métropole ; géométries annuelles selon le résumé du data paper | 1790–2020 | CC BY-NC 4.0 pour la v6 (septembre 2026) ; la v2 (avril 2026) et le data paper sont en CC BY 4.0 | Non indiquée. Méthode décrite en 2019 : reconstitution à rebours depuis le fichier IGN de 2015, avec la BD TOPO pour géoréférencer les cartes anciennes |
| **OpenStreetMap** (export data.gouv) | France, communes actuelles, tracées à partir du fond cadastral | Courant | ODbL | Variable |
| **OpenHistoricalMap** | Alsace-Lorraine aux niveaux national et régional seulement | Depuis 1852 | CC0 | Aucune commune alsacienne trouvée |
| **INSEE COG** | Listes, mouvements, tables de passage | Listes annuelles depuis 1999, mouvements depuis 1968 | Licence Ouverte | Aucune géométrie |

### Couverture selon les dates de recensement

| Recensement | Géométrie IGN officielle | Autre possibilité |
|---|---|---|
| 1968, 1975, 1982, 1990 | Aucune | COMMUNES, ou reconstitution |
| 1999 | GEOFLA 1997 ou 2002 : généralisée, et pas trouvée en téléchargement | Idem |
| 2006–2016 | GEOFLA 2010–2016 (généralisée) ; rien pour 2006–2009 | Idem |
| 2017 à aujourd'hui | ADMIN EXPRESS, une édition par an | — |

Mélanger les sources pose problème : GEOFLA s'écarte jusqu'à 1 km de la BD CARTO, alors qu'ADMIN EXPRESS est plus fin. Enchaîner GEOFLA puis ADMIN EXPRESS ferait apparaître des changements de limites qui n'en sont pas.

### Reconstituer les communes disparues

Depuis 1968, les mouvements du Bas-Rhin relèvent des types 10, 21, 31, 32, 33, 34, 35 et 71 du COG (`docs/modele-donnees.md`, §7.4).

| Situation | Contour retrouvable |
|---|---|
| Commune associée ou déléguée encore existante (types 32, 33) | Oui, couche des communes associées ou déléguées d'ADMIN EXPRESS |
| Commune rétablie (types 21, 71) | Oui, c'est une commune actuelle |
| Commune absorbée par fusion simple ou supprimée (types 31, 34, 35) | Peut-être, par réunion des sections cadastrales dont le préfixe porte son code INSEE. Non vérifié commune par commune |

Toutes ces méthodes donnent les **limites d'aujourd'hui** des anciennes communes, pas celles de l'époque. Les rectifications de limites entre deux recensements, qui ne sont pas des mouvements du COG, leur échappent.

---

## 3. Ce qui n'existe pas, d'après ces recherches

- Aucune série officielle IGN de contours communaux avant 1997.
- Aucun accès trouvé aux éditions GEOFLA 1997 et 2002.
- Aucun jeu ouvert, sans restriction commerciale et à précision documentée, qui donne les contours du Bas-Rhin à chaque recensement de 1968 à 1999.
- Aucun jeu historique du CIGAL (Alsace). Il propose en revanche des orthophotos de 1950-1951, utiles pour numériser des limites.

## 4. Points non vérifiés

- Le traitement de l'Alsace-Moselle par COMMUNES et sa précision : il faudrait télécharger l'archive (528 Mo) et lire ses README et le data paper.
- La possibilité de réutiliser la v2 de COMMUNES sous CC BY 4.0 alors que la v6 est en NC. Les licences Creative Commons sont en principe irrévocables pour une version déjà publiée, mais c'est à faire confirmer (Q9 du modèle).
- La précision officielle de l'édition d'ADMIN EXPRESS à retenir.

---

## 5. Sources consultées

- [Données limites administratives (data.gouv.fr)](https://www.data.gouv.fr/pages/donnees-geo)
- [GEOFLA® (data.gouv.fr)](https://data.gouv.fr/en/datasets/geofla-r), [GEOFLA® Communes 2016](https://www.data.gouv.fr/datasets/geofla-r-communes-2016-1/informations), [GEOFLA® Communes (geo.data.gouv.fr)](https://geo.data.gouv.fr/en/datasets/cac9f2c0de2d3a0209af2080854b6f6a7ee3d9f4), [descriptif GEOFLA 2.2](https://geoservices.ign.fr/sites/default/files/2021-07/DC_GEOFLA_2-2.pdf)
- [Métadonnées ADMIN EXPRESS (APUR)](https://geocatalogue.apur.org/catalogue/srv/api/records/a1d3c4a4-816e-45f5-8f39-2aa97e40de87), [descriptif ADMIN EXPRESS 3.0](https://geoservices.ign.fr/sites/default/files/2021-07/DC_DL_ADMIN_EXPRESS_3-0.pdf), [suivi des évolutions depuis la v4.0](https://geoservices.ign.fr/sites/default/files/2025-06/SE_ADMIN_EXPRESS_depuis_v4-0.pdf)
- [Licence IGN (liste OSM talk-fr, 2020)](https://lists.openstreetmap.org/pipermail/talk-fr/2020-January/096209.html), [précision ADMIN EXPRESS (liste OSM talk-fr, 2016)](https://lists.openstreetmap.org/pipermail/talk-fr/2016-December/082919.html)
- [Cadastre (data.gouv.fr)](https://www.data.gouv.fr/datasets/cadastre), [aide cadastre.gouv.fr sur le préfixe de section](https://www.cadastre.gouv.fr/scpc/html/aide/recherche/parcelle_en.htm)
- [French Historical GIS v6 (Zenodo)](https://zenodo.org/records/23011193), [v2 (Zenodo)](https://zenodo.org/records/19557567), [data paper (Cambridge)](https://www.repository.cam.ac.uk/handle/1810/407985), [projet ANR COMMUNE-HISDBD](https://anr.fr/Project-ANR-19-CE27-0005), [méthodologie CAMPOP](https://www.campop.geog.cam.ac.uk/research/projects/internationaloccupations/enchpopgos/france/gis.pdf)
- [Découpage communal issu d'OpenStreetMap (data.gouv.fr)](https://www.data.gouv.fr/datasets/decoupage-administratif-communal-francais-issu-d-openstreetmap), [OpenHistoricalMap](https://api.openhistoricalmap.org/way/198561569)
- [INSEE, Code officiel géographique](https://www.insee.fr/fr/information/8064273), [INSEE, historique des populations](https://www.insee.fr/fr/information/2414405)
- [Bilan CIGAL 2002–2015](https://www.datagrandest.fr/portail/fr/system/files/document/2016-05/1_bilancigal_2002-2015.pdf), [orthophoto Alsace 1950-51](https://www.data.gouv.fr/es/datasets/fr-236700019-carte-web-ortho-historique-50-51-5/)
