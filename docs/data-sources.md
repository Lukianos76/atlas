# Registre des sources de données

> **Statut** : validé par le mainteneur (2026-10-17).

Vue de pilotage des **jeux de données** envisagés, retenus ou écartés. Ce registre ne remplace ni les œuvres sources ni les citations enregistrées dans la base (`docs/modele-donnees.md`, §9) : à l'import, c'est la base qui fait foi. Il sert à décider *avant* d'importer, et à savoir ce qu'il reste à vérifier.

Règles :
- toute nouvelle source entre ici au statut « envisagée » ; son usage est validé par le mainteneur (CLAUDE.md, section « Pilotage », « Méthode ») ;
- la licence suit `docs/politique-editoriale.md` §4 : hors licences acceptées d'office (§4.3), elle est examinée par un humain au premier usage, et sa page est archivée à ce moment-là ;
- aucun champ n'est complété sans source : ce qui n'est pas établi reste « à renseigner » ou « à vérifier ».

Statuts : **envisagée** · **retenue** (usage décidé, pas encore importée) · **importée** · **citable seulement** (licence NC ou ND, §4.4) · **exclue**.

---

## IGN ADMIN EXPRESS

| Champ | Valeur |
|---|---|
| Producteur | IGN |
| Licence | Licence Ouverte Etalab (toutes les données publiques de l'IGN depuis 2021). Page archivée : à renseigner |
| Millésime ou édition | Une édition par an depuis 2017. Édition utilisée : à fixer (« édition récente ») |
| Couverture et granularité | France entière, communes en vigueur ; couche des communes associées ou déléguées au moins depuis la version 3.0 (mai 2021). Précision : à lire dans le descriptif de l'édition utilisée |
| Traitement | Contours courants des communes ; point dérivé (centre du plus grand cercle inscrit) |
| Statut | **retenue** (tranche 1) |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §1 et §2 |

## INSEE, Code officiel géographique (COG)

| Champ | Valeur |
|---|---|
| Producteur | INSEE |
| Licence | Licence Ouverte. Page archivée : à renseigner |
| Millésime ou édition | Listes annuelles depuis 1999, mouvements depuis 1968. Millésime utilisé : à fixer |
| Couverture et granularité | Listes, mouvements, tables de passage ; aucune géométrie |
| Traitement | Entités, événements et filiation (`docs/modele-donnees.md` §7.4) |
| Statut | **retenue** (tranche 1) |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §2 ; `docs/modele-donnees.md` §14.2 |

## INSEE, populations des recensements depuis 1968

| Champ | Valeur |
|---|---|
| Producteur | INSEE |
| Licence | À vérifier au premier usage (non documentée dans le dépôt) |
| Millésime ou édition | À renseigner |
| Couverture et granularité | Communes du Bas-Rhin, recensements depuis 1968 |
| Traitement | Observations originales, rattachées aux communes de chaque époque (§8.3) |
| Statut | **retenue** (tranche 1) |
| Origine de l'information | `docs/modele-donnees.md` §14.2 |

## INSEE, séries de population en géographie courante

| Champ | Valeur |
|---|---|
| Producteur | INSEE |
| Licence | À vérifier au premier usage (non documentée dans le dépôt) |
| Millésime ou édition | À renseigner |
| Couverture et granularité | Communes actuelles |
| Traitement | Dérivations externes, contrôlées par recalcul via le graphe de filiation (§8.4, Q13) ; valeur affichée par défaut |
| Statut | **retenue** (tranche 1) |
| Origine de l'information | `docs/modele-donnees.md` §14.2 et Q13 ; `docs/recherches/sources-geometries-historiques.md` §1 |

## IGN GEOFLA

| Champ | Valeur |
|---|---|
| Producteur | IGN |
| Licence | Licence Ouverte 1.0 |
| Millésime ou édition | 1997, 2002, puis de 2010 à 2016 (data.gouv.fr ne dit pas si c'était chaque année) ; production arrêtée. Seule la dernière édition est téléchargeable |
| Couverture et granularité | France entière, communes en vigueur à chaque édition ; généralisée, jusqu'à 1 000 m d'écart avec la BD CARTO |
| Traitement | À renseigner |
| Statut | **envisagée** |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §2 |

## Cadastre (PCI vecteur, export Etalab)

| Champ | Valeur |
|---|---|
| Producteur | À renseigner |
| Licence | Licence Ouverte |
| Millésime ou édition | État courant uniquement |
| Couverture et granularité | Toutes les communes en PCI vecteur depuis le 1er septembre 2025 ; précision cadastrale, mais le cadastre ne fait pas foi pour les limites |
| Traitement | Piste de repli : préfixes de section pour des géométries dérivées (`docs/backlog.md`) |
| Statut | **envisagée** |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §2 ; `docs/backlog.md` |

## Projet COMMUNES, version 6

| Champ | Valeur |
|---|---|
| Producteur | ANR COMMUNE-HISDBD (Litvine, Séguy, Thévenin ; CAMPOP, INED, ThéMA) |
| Licence | CC BY-NC 4.0 (septembre 2026) |
| Millésime ou édition | v6 |
| Couverture et granularité | Communes de métropole, 1790–2020 ; géométries annuelles selon le résumé du data paper ; précision non indiquée |
| Traitement | Aucun import (`docs/politique-editoriale.md` §4.4) |
| Statut | **citable seulement** |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §2 ; `docs/politique-editoriale.md` §4.4 |

## Projet COMMUNES, version 2

| Champ | Valeur |
|---|---|
| Producteur | ANR COMMUNE-HISDBD (Litvine, Séguy, Thévenin ; CAMPOP, INED, ThéMA) |
| Licence | CC BY 4.0 (avril 2026). Réutilisation à confirmer alors que la v6 est en NC |
| Millésime ou édition | v2 |
| Couverture et granularité | À évaluer (couverture, précision, Alsace-Moselle) |
| Traitement | À renseigner |
| Statut | **envisagée** (évaluation au backlog) |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §2 et §4 ; `docs/backlog.md` |

## OpenStreetMap et OpenHistoricalMap

| Champ | Valeur |
|---|---|
| Licence | ODbL (OpenStreetMap) ; CC0 (OpenHistoricalMap) |
| Traitement | Aucun : outils pour trouver la source d'origine. Seule exception : un identifiant OSM est une assertion d'identifiant (`docs/politique-editoriale.md` §3.3) |
| Statut | **exclue** comme source |
| Origine de l'information | `docs/recherches/sources-geometries-historiques.md` §2 ; `docs/politique-editoriale.md` §3.3 |
