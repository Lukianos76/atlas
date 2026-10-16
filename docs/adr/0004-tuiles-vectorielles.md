# ADR 0004 — Format et génération des tuiles vectorielles

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

Les tuiles doivent servir des géométries **versionnées dans le temps**, pour plusieurs systèmes de découpage et plusieurs points de vue, du monde entier jusqu'au quartier. Le modèle fait de l'**état matérialisé** (T, point de vue, R) l'objet affiché et cité (`docs/modele-donnees.md`, §10.4) : ce qui est publié doit être stable et reproductible.

Les tuiles alimentent MapLibre GL JS (ADR 0001) et deck.gl (ADR 0002). Elles doivent rester peu coûteuses à diffuser pour un projet ouvert et contributif.

La cible finale est mondiale : les archives de tuiles, fond de carte compris, se comptent en dizaines voire centaines de gigaoctets. Leur taille et leur coût de diffusion sont des critères de premier rang.

Vérifications faites avec Context7 (octobre 2026) :

- **PMTiles** est une archive en un seul fichier, lue par requêtes HTTP partielles depuis un stockage objet (S3, R2, GCS). MapLibre la lit grâce au protocole `pmtiles://` (`addProtocol`) ;
- **Tippecanoe** (maintenu par Felt) écrit directement du PMTiles. `--coalesce-densest-as-needed` gère les petits zooms. `--no-simplification-of-shared-nodes` remplace l'option dépréciée `--detect-shared-borders` pour simplifier de façon identique les bords communs ;
- **Martin** sert des tuiles dynamiques depuis des tables et des fonctions PostGIS, avec des paramètres de requête (`query_params`). `martin cp` sait générer des archives ;
- **MapLibre GL JS** lit le nouveau format **MLT** en plus de MVT.

## Options envisagées

**Diffusion :**

| Option | Points forts | Limites |
|---|---|---|
| A. Tuiles statiques PMTiles générées depuis PostGIS | Aucun serveur : un fichier sur un CDN, coût minime, très rapide. Une archive par état matérialisé publié donne un support de citation figé | À regénérer à chaque publication. Pas d'aperçu immédiat d'une contribution |
| B. Tuiles dynamiques Martin, depuis des fonctions PostGIS paramétrées par date, point de vue et R | Toujours à jour. Toute combinaison est possible | Serveur et base sollicités à chaque tuile non mise en cache. Cache plus délicat. Coût et exploitation |
| **C. Hybride** | La rapidité de A pour le public, la souplesse de B pour l'édition | Deux chaînes à maintenir |

**Format :** MVT, le standard actuel, ou MLT, plus compact mais avec un outillage de production moins mûr.

**Générateur des archives statiques :** Tippecanoe à partir d'exports PostGIS, ou `martin cp` directement depuis les fonctions PostGIS, avec une généralisation à écrire soi-même (par exemple avec `ST_CoverageSimplify`).

**Contenu des tuiles :** valeurs statistiques intégrées aux tuiles, ou tuiles limitées aux géométries et identifiants avec des valeurs jointes côté client.

**Fond de carte sombre :** Protomaps Basemaps auto-hébergé, un fond tiers hébergé (CARTO Dark Matter, MapTiler), ou un fond maison minimal (Natural Earth).

## Décision

1. **Diffusion hybride, par étapes** :
   - dès la tranche 1, des **PMTiles statiques**, une archive par état matérialisé publié ;
   - avec l'ouverture à la contribution, des tuiles dynamiques **Martin** (fonctions PostGIS paramétrées par date, point de vue et date d'enregistrement), pour la prévisualisation et les combinaisons rares.
2. **Format MVT**. MLT sera réévalué quand son outillage de production sera mûr.
3. **Générateur : Tippecanoe**, à partir d'exports de PostGIS.
4. **Tuiles = géométries + identifiant d'entité**. Les valeurs statistiques sont chargées à part et jointes côté client par identifiant (`feature-state` de MapLibre, attributs de deck.gl).
5. **Fond de carte sombre : Protomaps Basemaps**, auto-hébergé et recoloré par un style MapLibre propre à l'atlas.

## Conséquences

- Le public reçoit des fichiers statiques sur CDN : aucun serveur de tuiles n'est nécessaire en tranche 1 (hébergement : ADR 0007).
- Chaque état matérialisé publié a son archive : citer l'atlas, c'est citer une archive figée, ce qui rejoint le §10.4 du modèle.
- Changer de variable ou de millésime ne demande pas de regénérer les tuiles : seules les valeurs sont rechargées. Un format d'échange des valeurs, indexées par identifiant d'entité, est à définir.
- Une chaîne d'export PostGIS → Tippecanoe est à écrire dans les pipelines (ADR 0006). Les réglages de généralisation par zoom sont à mettre au point sur les polygones indépendants du modèle.
- Martin n'entre en jeu qu'avec la contribution. Ses fonctions SQL devront produire des géométries cohérentes avec celles des archives statiques.
- Le fond de carte ne dépend d'aucun service tiers. L'archive mondiale Protomaps est volumineuse : son stockage et sa diffusion relèvent de l'ADR 0007.
