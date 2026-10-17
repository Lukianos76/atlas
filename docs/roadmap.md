# Roadmap

> **Statut** : proposé. Jalons et ordre de priorité proposés, en attente de validation par le mainteneur.

Jalons engagés et tâches, par ordre de priorité : la prochaine tâche est la première non cochée, ni bloquée ni en cours, du premier jalon non terminé (`/next-task`). Les tâches identifiées mais non engagées vivent dans `docs/backlog.md` ; une tâche n'en sort qu'avec l'accord du mainteneur.

Conventions :
- `- [ ]` à faire, `- [x]` fait ;
- annotations : *en cours : branche `x`*, *bloqué : raison* ;
- chaque tâche indique sa spec (`docs/specs/x.md`, ou « à rédiger ») et le document qui l'a fait naître.

## Jalon 0. Pilotage

- [x] **Mettre en place le pilotage par Claude Code** : sous-agents, skills, hooks, roadmap, specs, registre des sources. Spec : sans objet (plan validé en conversation). Branche `chore/pilotage-claude-code`.

## Jalon 1. Prérequis de la base de référence

Origine : `docs/schema.md`, section 4 (déplacées de `docs/backlog.md`).

- [ ] **Sauvegarde hors de la machine de la base de référence.** Prérequis au premier import de la tranche 1 : la base doit être sauvegardée hors de la machine dès le premier lot validé. Ses identifiants internes, publiés dans les tuiles et les fichiers de valeurs, ne sont jamais réattribués : la base ne peut pas être reconstruite par réimport. Spec : à rédiger.
- [ ] **Identifiants du superutilisateur hors du `.env`.** Prérequis au premier import de la tranche 1 (`docs/schema.md`, §5.13) : le `.env` lu par les pipelines et par Claude Code ne contient plus que les identifiants d'un rôle d'import. Le superutilisateur et `atlas_owner` sont saisis de façon interactive par `scripts/db-ref-migrate.sh`, parce qu'un superutilisateur peut prendre n'importe quel rôle et contourner la séparation des droits. Spec : à rédiger.
- [ ] **Script de création des rôles de connexion.** Un rôle par contributeur, membre d'`atlas_import` ou d'`atlas_review`, avec un mot de passe demandé de façon interactive et jamais écrit dans un fichier du dépôt ; enregistrement du contributeur correspondant (`contributor.db_role`). Spec : à rédiger.

## Jalon 2. Tranche 1 : imports

Origine : `docs/modele-donnees.md` §14.2 (population communale du Bas-Rhin, recensements depuis 1968) et `docs/recherches/sources-geometries-historiques.md` §1. Chaque lot suit la règle d'acceptation du §10.5.

- [ ] **Référentiel COG et mouvements depuis 1968**, traduits en entités, événements et filiation (`docs/modele-donnees.md` §7.4). Spec : à rédiger.
- [ ] **Populations des recensements depuis 1968**, observations originales rattachées aux communes de chaque époque (§8.3). Spec : à rédiger.
- [ ] **Contours ADMIN EXPRESS** (édition récente) et point dérivé de chaque commune : centre du plus grand cercle inscrit dans son contour (§6.1, §14.2). Spec : à rédiger.
- [ ] **Séries de l'INSEE en géographie courante**, importées comme dérivations externes et contrôlées par recalcul via le graphe de filiation (§8.4, Q13). Spec : à rédiger.
- [ ] **Taux d'évolution annuel moyen**, observation dérivée interne entre deux dates espacées d'au moins cinq ans (§8.4, §14.2). Spec : à rédiger.

## Jalon 3. Tranche 1 : carte

Origine : `docs/modele-donnees.md` §14.2, ADR 0002, 0004, 0008 et 0011.

- [ ] **Publication des tuiles**, avec les trois contrôles d'export de l'ADR 0004. Spec : à rédiger.
- [ ] **Cercles proportionnels de population**, placés sur le point dérivé (§14.2, ADR 0002). Spec : à rédiger.
- [ ] **Choroplèthe du taux d'évolution annuel moyen** : palette divergente centrée sur 0, seuils fixés dans la fiche de la variable (§14.2 ; `docs/politique-editoriale.md` §5.4). Spec : à rédiger.
- [ ] **Curseur temporel** (ADR 0008). Spec : à rédiger.
- [ ] **Mention « territoire des communes actuelles »** pour les valeurs passées (§14.2). Spec : à rédiger.
- [ ] **Affichage des sources** de chaque donnée affichée (`docs/vision.md`, pilier « fiabilité »). Spec : à rédiger.
- [ ] **Lien vers le code source dans l'interface.** Le JavaScript envoyé au navigateur est généralement considéré comme une distribution du programme : l'application indique où trouver son code source (ADR 0011 ; déplacé de `docs/backlog.md`). Spec : à rédiger.
