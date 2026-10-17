# Registre des jeux de données

Toute donnée importée provient d'un jeu inscrit ici au statut `validée` (CLAUDE.md, règle 1). Une fiche est proposée par Claude Code ou par un contributeur, évaluée par le sous-agent `data-verifier` au regard de la politique éditoriale (§3 et §4), puis passe à `validée` sur décision du mainteneur. Licence et édition sont relevées sur la page de l'éditeur, dont l'URL et la date de consultation sont notées. Ce qui n'a pas pu être confirmé est écrit « à vérifier », jamais supposé.

Le registre décrit des **jeux de données**. Il ne remplace pas les citations : chaque assertion et chaque observation portent leur propre citation, avec son localisateur (`docs/modele-donnees.md`, §9).

## Fiche type

| Champ | Contenu |
|---|---|
| Identifiant | Court et stable (ex. `insee-cog`) |
| Intitulé, producteur | |
| URL de référence | Page de l'éditeur |
| Licence | Nom exact et lien vers le texte ; conformité aux §4.3 et §4.4 de la politique éditoriale |
| Édition ou millésime | |
| Date de consultation | AAAA-MM-JJ |
| Granularité | Spatiale et temporelle |
| Couverture | Territoire et période |
| Méthode de traitement | Pipeline, transformations, contrôles |
| Évaluation | Rang selon le §3.2, accessibilité et pérennité (§3.5), réserves ; avis de `data-verifier` |
| Statut | `proposée` ; `validée` (date, par qui) ; `écartée` (raison) |
| Utilisée par | Tâches de `docs/roadmap.md`, variables |

## Sources

### `insee-cog` — Code officiel géographique (INSEE)

| Champ | Contenu |
|---|---|
| Intitulé, producteur | Code officiel géographique (COG), Institut national de la statistique et des études économiques (INSEE) |
| URL de référence | <https://www.insee.fr/fr/information/2560452> (« Code officiel géographique (COG) — Téléchargement des fichiers ») ; page d'ensemble : <https://www.insee.fr/fr/information/8064273> |
| Licence | À vérifier : aucune licence n'apparaît sur ces pages. `docs/recherches/sources-geometries-historiques.md` indique « Licence Ouverte », à confirmer sur les mentions légales de l'INSEE |
| Édition ou millésime | Millésimes 1999 à 2026 ; page mise à jour le 2026-02-24 |
| Date de consultation | 2026-10-17 |
| Granularité | Communes, cantons, arrondissements, départements, régions ; historique des couples code-libellé de commune depuis 1943 |
| Couverture | France |
| Méthode de traitement | À définir avec T2.1 (traduction des mouvements, `docs/modele-donnees.md`, §7.4). Le fichier des mouvements n'est pas cité sur la page consultée : à vérifier |
| Évaluation | À rendre par `data-verifier` |
| Statut | `proposée` |
| Utilisée par | T2.1 |

### `ign-admin-express` — ADMIN EXPRESS (IGN)

| Champ | Contenu |
|---|---|
| Intitulé, producteur | ADMIN EXPRESS et variantes (ADMIN EXPRESS COG, COG CARTO, COG CARTO PE, COG CARTO PLUS PE), Institut national de l'information géographique et forestière (IGN) |
| URL de référence | <https://www.data.gouv.fr/datasets/admin-express/> ; source originale sur cartes.gouv.fr (catalogue `IGNF_ADMIN-EXPRESS`, page non lisible lors de la consultation) |
| Licence | Licence Ouverte / Open Licence 2.0 (Etalab), selon data.gouv.fr ; à confirmer sur cartes.gouv.fr |
| Édition ou millésime | À choisir : fiche data.gouv.fr mise à jour le 2026-10-09. Les variantes COG suivent le COG au 1er janvier de l'année |
| Date de consultation | 2026-10-17 |
| Granularité | Découpage administratif, communes comprises ; détail des couches et précision dans le descriptif de l'édition retenue, à lire |
| Couverture | Métropole et départements d'outre-mer, à la date d'extraction |
| Méthode de traitement | À définir avec T2.4 |
| Évaluation | À rendre par `data-verifier` |
| Statut | `proposée` |
| Utilisée par | T2.4, T3.2 |

### `insee-historique-populations` — Historique des populations communales (INSEE)

| Champ | Contenu |
|---|---|
| Intitulé, producteur | « Historique des populations communales — Recensements de la population 1876-2023 », INSEE |
| URL de référence | <https://www.insee.fr/fr/statistiques/3698339> ; présentation : <https://www.insee.fr/fr/information/2414405> |
| Licence | À vérifier : aucune licence n'apparaît sur ces pages |
| Édition ou millésime | Publication du 2025-12-18, géographie en vigueur au 1er janvier 2025 ; fichier `base-pop-historiques-1876-2023.xlsx` |
| Date de consultation | 2026-10-17 |
| Granularité | Commune (arrondissements municipaux pour Paris ; Lyon et Marseille entières) ; un recensement par colonne |
| Couverture | France hors Mayotte ; France continentale 1876-2023 |
| Méthode de traitement | À définir avec T2.5 : dérivation externe en géographie courante (Q13), recalculée par le graphe de filiation |
| Évaluation | À rendre par `data-verifier`. Réserves relevées sur la page : la variable change selon la période (population totale jusqu'en 1954, sans doubles comptes de 1962 à 1999, municipale depuis 2006), et les millésimes depuis 2006 ne se comparent qu'à au moins 5 ans d'écart, **6 ans pour 2019 à 2023** |
| Statut | `proposée`. Candidate pour les « séries de l'INSEE en géographie courante » du modèle (§14.2), à confirmer |
| Utilisée par | T2.5, T3.2, T3.3 |

## Sources examinées et écartées

### COMMUNES v6 (projet ANR COMMUNE-HISDBD)

CC BY-NC 4.0 : citable, jamais importée (`docs/politique-editoriale.md`, §4.4). La v2, sous CC BY 4.0, reste à évaluer (`docs/roadmap.md`, section Non priorisé). Détail dans `docs/recherches/sources-geometries-historiques.md`.
