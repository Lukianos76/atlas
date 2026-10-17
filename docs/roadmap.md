# Roadmap

> **Statut** : phases, ordre, objectifs, critères de sortie et décisions à prendre fixés par le mainteneur (2026-10-17). Le découpage en tâches et les renvois aux documents sont proposés par Claude, en attente de validation.

Phases et tâches, par ordre de priorité : la prochaine tâche est la première non cochée, ni bloquée ni en cours, de la première phase non terminée (`/next-task`). Les tâches identifiées mais non engagées vivent dans `docs/backlog.md` ; une tâche n'en sort qu'avec l'accord du mainteneur.

Conventions :
- `- [ ]` à faire, `- [x]` fait ;
- annotations : *en cours : branche `x`*, *bloqué : raison*, *mainteneur* (tâche que seul le mainteneur peut faire : CLAUDE.md, règles 6 et 9) ;
- chaque tâche indique sa spec (`docs/specs/x.md`, ou « à rédiger ») et le document qui l'a fait naître.

## Phase 0. Pilotage

- [x] **Mettre en place le pilotage par Claude Code** : sous-agents, skills, hooks, roadmap, specs, registre des sources. Spec : sans objet (plan validé en conversation). Branche `chore/pilotage-claude-code`.

## Phase 1. Tranche 1 : le Bas-Rhin depuis 1968

**Objectif** : une première carte publique, où chaque valeur renvoie à sa source. C'est la preuve que le modèle tient sur de vraies données (`docs/modele-donnees.md` §14.2).

**Critère de sortie** : une adresse publique où l'on voit le Bas-Rhin de 1968 à aujourd'hui, chaque valeur sourcée, le recalcul égal aux séries INSEE là où les transferts sont totaux.

**Décisions à prendre** : le fournisseur d'hébergement (ADR 0007) ; l'avis juridique, que la politique éditoriale recommande avant la première publication (`docs/politique-editoriale.md` §4.2).

### Base

- [ ] **Migrations du schéma et tests de violation**, sur la base de développement (`docs/schema.md`, §12). Spec : à rédiger.
- [ ] **Identifiants du superutilisateur hors du `.env`.** *Mainteneur.* Le `.env` lu par les pipelines et par Claude Code ne contient plus que les identifiants d'un rôle d'import. Le superutilisateur et `atlas_owner` sont saisis de façon interactive par `scripts/db-ref-migrate.sh`, parce qu'un superutilisateur peut prendre n'importe quel rôle et contourner la séparation des droits (`docs/schema.md`, §5.13). Spec : à rédiger.
- [ ] **Rôles de connexion.** *Mainteneur.* Un rôle par contributeur, membre d'`atlas_import` ou d'`atlas_review`, avec un mot de passe demandé de façon interactive et jamais écrit dans un fichier du dépôt ; enregistrement du contributeur correspondant (`contributor.db_role`). Le script de création peut être préparé par Claude. Spec : à rédiger.
- [ ] **Sauvegarde hors de la machine de la base de référence.** *Mainteneur.* La base doit être sauvegardée hors de la machine dès le premier lot validé. Ses identifiants internes, publiés dans les tuiles et les fichiers de valeurs, ne sont jamais réattribués : la base ne peut pas être reconstruite par réimport (`docs/schema.md`, section 4). Spec : à rédiger.
- [ ] **Migration de la base de référence**, depuis `main` (`scripts/db-ref-migrate.sh`, ADR 0010). *Mainteneur.* Spec : sans objet.

### Outillage d'import

- [ ] **Skill « ajouter un jeu de données »** et **sous-agent ingénieur données.** Spec : à rédiger.

### Imports

Chaque lot suit la règle d'acceptation du `docs/modele-donnees.md` §10.5.

- [ ] **Lot COG** : entités, codes, mouvements traduits selon le §7.4. Spec : à rédiger.
- [ ] **Lot ADMIN EXPRESS** : contours des communes actuelles. Spec : à rédiger.
- [ ] **Lot séries INSEE en géographie courante**, importées comme dérivations externes (§8.4, Q13). C'est là que se posera la question des deux concepts de population, avant et après 2006. Spec : à rédiger.
- [ ] **Recalcul par le graphe de filiation**, comparé aux séries INSEE : le vrai test du modèle (Q13). Spec : à rédiger.

### Publication

- [ ] **Chaîne de publication** : export, Tippecanoe, PMTiles, fichiers Parquet, manifeste, les trois contrôles d'export (ADR 0004, ADR 0009). Spec : à rédiger.

### Front

- [ ] **Cercles proportionnels de population** (§14.2, ADR 0002). Spec : à rédiger.
- [ ] **Taux d'évolution annuel moyen** en choroplèthe (§14.2 ; `docs/politique-editoriale.md` §5.4). Spec : à rédiger.
- [ ] **Curseur temporel** (ADR 0008). Spec : à rédiger.
- [ ] **Légende complète**, avec la mention « territoire des communes actuelles » pour les valeurs passées (§14.2). Spec : à rédiger.
- [ ] **Infobulle des sources.** Spec : à rédiger.
- [ ] **Clause de non-responsabilité.** Spec : à rédiger.
- [ ] **Lien vers le code source.** Le JavaScript envoyé au navigateur est généralement considéré comme une distribution du programme : l'application indique où trouver son code source (ADR 0011). Spec : à rédiger.

### Hébergement

- [ ] **Hébergement statique**, avec le choix du fournisseur (ADR 0007). Spec : à rédiger.

## Phase 2. La France entière, mêmes données

**Objectif** : tester le passage à l'échelle avant de compliquer le modèle. Mêmes sources sur 35 000 communes ; si le schéma doit évoluer, c'est beaucoup moins coûteux maintenant qu'avec des données historiques et contributives par-dessus.

**Critère de sortie** : la France entière navigable avec fluidité, et les résultats du banc d'essai consignés dans les ADR.

- [ ] **Imports France entière** : COG, ADMIN EXPRESS, séries INSEE. Spec : à rédiger.
- [ ] **Banc d'essai de l'ADR 0006** : indexation, partitionnement, performances des tuiles et du Parquet ; résultats consignés dans les ADR. Spec : à rédiger.
- [ ] **Fond de carte Protomaps.** Spec : à rédiger.
- [ ] **Chargement différé du front.** Spec : à rédiger.

## Phase 3. Tranche 2 : l'Alsace-Moselle de 1871 à 1945

**Objectif** : le premier vrai test du pilier « temps », et ce qui distinguera l'atlas de tout ce qui existe.

**Décisions à prendre** : Q7 (nom par défaut), Q14 (souveraineté portée par un territoire) et Q15 (correspondance entre niveaux) (`docs/modele-donnees.md` §14.2) ; vérification de la qualification du Bezirk sur l'acte allemand.

- [ ] **Géométries historiques** (`docs/recherches/sources-geometries-historiques.md`) :
  - [ ] **Évaluer COMMUNES v2 (CC BY 4.0)** : couverture, précision, traitement de l'Alsace-Moselle, et possibilité juridique de la réutiliser alors que la v6 est passée en CC BY-NC 4.0. La v6 elle-même ne peut pas être importée : une source NC est citable, jamais importée (`docs/politique-editoriale.md`, §4.4).
  - [ ] **Prendre contact avec l'équipe du projet COMMUNES** (ANR COMMUNE-HISDBD). *Mainteneur* ; Claude prépare le message.
  - [ ] **Reconstitution, piste de repli** : produire des géométries **dérivées** (§6.1 et §8.4 du modèle) à partir d'ADMIN EXPRESS (communes associées ou déléguées), des préfixes de section du cadastre et des mouvements du COG, en assumant qu'elles portent les limites actuelles.
- [ ] **Points de vue, préférences et états matérialisés**, qui deviennent des tables (§10.2 à §10.4). Spec : à rédiger.
- [ ] **Autorités concurrentes et noms selon l'autorité** (Strasbourg et Straßburg) (§5.6, Q7). Spec : à rédiger.
- [ ] **Recensements allemands**, avec la correspondance entre variables et entre niveaux (§12.4, Q15). Spec : à rédiger.
- [ ] **L'annexion de 1940 à 1944**, premier affichage « disputé » (`docs/politique-editoriale.md` §2). Spec : à rédiger.

## Phase 4. Les élections

**Objectif** : la première donnée ventilée par dimensions, et la plus attendue du grand public.

**Décision à prendre** : Q10 (les entités non géographiques : partis, candidats, scrutins).

- [ ] **Dimensions et membres** (§8.2). Spec : à rédiger.
- [ ] **Partis comme entités** qui naissent, fusionnent et se scindent (Q10). Spec : à rédiger.
- [ ] **Table des couleurs sourcées** (`docs/politique-editoriale.md` §5.2). Spec : à rédiger.
- [ ] **Carte du vainqueur et carte des scores** (`docs/politique-editoriale.md` §5.3). Spec : à rédiger.
- [ ] **Mode daltonien** (`docs/politique-editoriale.md` §5.6). Spec : à rédiger.
- [ ] **Import des résultats électoraux** publiés par l'État, d'abord par commune. Spec : à rédiger.

## Phase 5. Les flux et l'identité lumineuse

**Objectif** : tenir la promesse visuelle de la vision, les données qui « éclairent » le territoire.

- [ ] **deck.gl** (ADR 0002), avec le prototype de compatibilité avec le globe. Spec : à rédiger.
- [ ] **Arcs, densités et mélange additif.** Spec : à rédiger.
- [ ] **Import de flux entre communes** : migrations résidentielles ou déplacements domicile-travail de l'INSEE, qui exercent les rôles d'entité multiples du modèle. Spec : à rédiger.

## Phase 6. Le monde

**Objectif** : passer du national au mondial.

- [ ] **Pays et subdivisions, codes ISO, données internationales.** Spec : à rédiger.
- [ ] **Globe aux petits zooms.** Spec : à rédiger.
- [ ] **Territoires disputés actuels** (Crimée, Cachemire) et point de vue de reconnaissance internationale (§13 ; `docs/politique-editoriale.md` §2). Spec : à rédiger.
- [ ] **Sous-partitionnement des observations** (`docs/schema.md` §6) et **ordre spatial des fichiers de valeurs** (ADR 0009). Spec : à rédiger.

## Phase 7. L'ouverture à la contribution

**Objectif** : le pilier de l'intelligence collective.

**Décisions à prendre**, avant la première contribution extérieure : les conditions de contribution pour le code et pour les données. Réexaminer des conditions de contribution qui n'autorisent un changement de licence que vers une autre licence libre, alignées sur celles prévues pour les données (`docs/politique-editoriale.md`, §4.2 ; ADR 0011). D'ici là, les contributions sont acceptées sous DCO.

- [ ] **Serveur dédié de l'ADR 0007** et son exploitation : sauvegardes, mises à jour, supervision. Spec : à rédiger.
- [ ] **Authentification, API de contribution, tuiles dynamiques Martin** pour prévisualiser une proposition. Spec : à rédiger.
- [ ] **Interface de proposition, de relecture et de contestation**, qui s'appuie sur le cycle de vie des révisions du modèle (§10.1). Spec : à rédiger.
- [ ] **Gouvernance** : la procédure communautaire de décision prévue par la politique éditoriale (§6.4), et la protection contre le vandalisme. Spec : à rédiger.

## Phase 8. L'échelle fine

**Objectif** : le quartier, dernier palier de la vision. Les volumes y changent d'ordre de grandeur, ce qui justifie de garder cette phase pour la fin, quand l'architecture aura fait ses preuves.

- [ ] **IRIS.** Spec : à rédiger.
- [ ] **Données carroyées.** Spec : à rédiger.
- [ ] **Bureaux de vote.** Spec : à rédiger.

## Chantiers continus

En parallèle de toutes les phases. Les tâches ponctuelles qui en naissent sont ajoutées à la phase en cours.

- **Juridique** : l'avis juridique avant la première publication, avec la question du code produit par une IA (`docs/politique-editoriale.md` §4.2) ; puis les conditions de contribution (phase 7).
- **Sécurité et exploitation** : sauvegardes testées (une sauvegarde qu'on n'a jamais restaurée n'en est pas une), mises à jour des dépendances.
- **Qualité** : la CI, les tests de violation, l'accessibilité, un budget de performance pour le front.
- **Documentation** : chaque écart passe par une révision proposée du document concerné.
- **Communauté** : un README qui donne envie, puis les premiers partenaires, à commencer par l'équipe COMMUNES.
