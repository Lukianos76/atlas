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
| A. Tuiles statiques PMTiles générées depuis PostGIS | Aucun serveur : un fichier sur un CDN, coût minime, très rapide. Une archive publiée et figée sert de support de citation | À regénérer à chaque publication. Pas d'aperçu immédiat d'une contribution |
| B. Tuiles dynamiques Martin, depuis des fonctions PostGIS paramétrées par date, point de vue et R | Toujours à jour. Toute combinaison est possible | Serveur et base sollicités à chaque tuile non mise en cache. Cache plus délicat. Coût et exploitation |
| **C. Hybride** | La rapidité de A pour le public, la souplesse de B pour l'édition | Deux chaînes à maintenir |

**Format :** MVT, le standard actuel, ou MLT, plus compact mais avec un outillage de production moins mûr.

**Générateur des archives statiques :** Tippecanoe à partir d'exports PostGIS, ou `martin cp` directement depuis les fonctions PostGIS, avec une généralisation à écrire soi-même (par exemple avec `ST_CoverageSimplify`).

**Contenu des tuiles :** valeurs statistiques intégrées aux tuiles, ou tuiles limitées aux géométries et identifiants avec des valeurs jointes côté client.

**Fond de carte sombre :** Protomaps Basemaps auto-hébergé, un fond tiers hébergé (CARTO Dark Matter, MapTiler), ou un fond maison minimal (Natural Earth).

## Décision

1. **Diffusion hybride, par étapes** :
   - dès la tranche 1, des **PMTiles statiques**, **une archive par période historique** (par exemple 1968 à aujourd'hui pour la tranche 1). L'archive contient **toutes les versions** des géométries valides sur la période, avec leurs **bornes de validité en attributs**. Le navigateur filtre les versions selon la date affichée : le curseur temporel ne recharge aucune tuile et reste fluide ;
   - avec l'ouverture à la contribution, des tuiles dynamiques **Martin** (fonctions PostGIS paramétrées par date, point de vue et date d'enregistrement), pour la prévisualisation et les combinaisons rares.
2. **Publication immuable.** Une **publication** réunit l'archive et ses fichiers de valeurs (format : ADR 0009). Elle est publiée, versionnée et immuable, sous **un même identifiant de publication**. La publication fixe le point de vue et la date d'enregistrement R ; la date T est choisie dans le navigateur. Citer l'atlas, c'est citer (identifiant de publication, T), ce qui rend reproductible le triplet (T, point de vue, R) du §10.4 du modèle.
3. **Format MVT**. MLT sera réévalué quand son outillage de production sera mûr.
4. **Générateur : Tippecanoe**, à partir d'exports de PostGIS.
5. **Tuiles = géométries + identifiant d'entité + bornes de validité**. Les valeurs statistiques sont chargées à part et jointes côté client par identifiant (`feature-state` de MapLibre, attributs de deck.gl).
6. **Fond de carte sombre : Protomaps Basemaps**, auto-hébergé et recoloré par un style MapLibre propre à l'atlas.

## Conséquences

- Le public reçoit des fichiers statiques sur CDN : aucun serveur de tuiles n'est nécessaire en tranche 1 (hébergement : ADR 0007).
- Les versions d'une même entité partagent son identifiant, mais une seule est visible à une date T. L'identifiant d'entité peut donc être promu (`promoteId`) pour la jointure des valeurs.
- La taille des tuiles croît avec le nombre de versions d'une période : c'est ce qui justifie le découpage en périodes.
- **À vérifier** : que `--coalesce-densest-as-needed` de Tippecanoe ne fusionne pas des versions aux bornes de validité différentes ; sinon, l'option est écartée pour ces archives.
- **Question ouverte** : les bornes à écrire dans les tuiles quand une date est floue (ADR 0003). La tranche 1 n'en a pas besoin : ses dates, issues du COG, sont exactes.
- Changer de variable ou de millésime ne demande pas de regénérer les tuiles : seules les valeurs sont rechargées.
- Une publication ne se modifie jamais : toute correction produit une nouvelle publication, sous un nouvel identifiant.
- Une chaîne d'export PostGIS → Tippecanoe est à écrire dans les pipelines (ADR 0006). Les réglages de généralisation par zoom sont à mettre au point sur les polygones indépendants du modèle.
- Martin n'entre en jeu qu'avec la contribution. Ses fonctions SQL devront produire des géométries cohérentes avec celles des archives statiques.
- Le fond de carte ne dépend d'aucun service tiers. L'archive mondiale Protomaps est volumineuse : son stockage et sa diffusion relèvent de l'ADR 0007.
