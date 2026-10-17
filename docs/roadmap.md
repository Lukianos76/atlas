# Feuille de route

Jalons ordonnés par priorité, du plus urgent au moins urgent ; dans un jalon, les tâches sont dans l'ordre où les mener. **L'ordre est fixé par le mainteneur** : celui-ci est une proposition, tirée du périmètre de la tranche 1 (`docs/modele-donnees.md`, §14.2), des prérequis déjà écrits et de l'état du dépôt.

Format d'une tâche : `- [ ] **Tx.y** intitulé — spec : lien. Dépend de : … Origine : …`. États : case vide (à faire), `(en cours)`, `(bloquée : raison)`, case cochée (fait).

Une tâche est menée par `/next-task` ; une tâche sans spec en reçoit une par `/new-spec`. Les tâches identifiées mais pas encore priorisées sont en fin de document, avec le document qui les a fait naître.

## J0 — Socle

- [x] **T0.1** Squelette du monorepo. Origine : ADR 0005.
- [x] **T0.2** ADR 0001 à 0011, modèle de données, politique éditoriale, glossaire.
- [x] **T0.3** Schéma logique de la tranche 1. Origine : `docs/schema.md`.
- [ ] **T0.4** Migrations initiales et tests des invariants de la base (en cours : branche `feat/schema-tranche-1`, à fusionner). Origine : `docs/schema.md`, ADR 0010.
- [ ] **T0.5** Pilotage du projet par Claude Code : roadmap, specs, registre des sources, sous-agents, commandes, hooks (en cours : branche `chore/pilotage-claude`).

## J1 — Prérequis du premier import

Origine : `docs/schema.md`, sections 4 et 5.13.

- [ ] **T1.1** **Sauvegarde hors de la machine de la base de référence.** Prérequis au premier import de la tranche 1 : la base doit être sauvegardée hors de la machine dès le premier lot validé. Ses identifiants internes, publiés dans les tuiles et les fichiers de valeurs, ne sont jamais réattribués : la base ne peut pas être reconstruite par réimport.
- [ ] **T1.2** **Identifiants du superutilisateur hors du `.env`.** Prérequis au premier import de la tranche 1 (`docs/schema.md`, §5.13) : le `.env` lu par les pipelines et par Claude Code ne contient plus que les identifiants d'un rôle d'import. Le superutilisateur et `atlas_owner` sont saisis de façon interactive par `scripts/db-ref-migrate.sh`, parce qu'un superutilisateur peut prendre n'importe quel rôle et contourner la séparation des droits.
- [ ] **T1.3** **Script de création des rôles de connexion.** Un rôle par contributeur, membre d'`atlas_import` ou d'`atlas_review`, avec un mot de passe demandé de façon interactive et jamais écrit dans un fichier du dépôt ; enregistrement du contributeur correspondant (`contributor.db_role`).

## J2 — Tranche 1 : import

Population communale du Bas-Rhin, recensements français depuis 1968, sur la géographie communale du COG et son historique (`docs/modele-donnees.md`, §14.2). Chaque import suit la règle d'acceptation des lots (§10.5) et ne commence qu'avec une source au statut `validée` dans `docs/data-sources.md`.

- [ ] **T2.1** Import du COG et de son historique : communes et mouvements, traduits selon le §7.4 du modèle. Dépend de : J1.
- [ ] **T2.2** **Chargement du fichier des variables (N8).** Déclencheur : *première variable de la tranche 1.* Charger `db/reference/variables.toml` (seuils de discrétisation et leur justification, réponse A20) dans `variable`. Origine : `docs/schema.md`, sections 8.5 et 9.
- [ ] **T2.3** **Copie archivée exigée à la validation (N3).** Déclencheur : *avec la procédure d'import de la tranche 1.* Contrôle, par le trigger de validation, de la copie archivée d'une citation lors du passage à `validated` (politique éditoriale §3.5), avec une colonne d'exception justifiée sur `citation`. Origine : `docs/schema.md`, sections 8.5 et 9.
- [ ] **T2.4** Import des contours d'ADMIN EXPRESS (géographie courante). Dépend de : T2.1.
- [ ] **T2.5** Import des séries de l'INSEE en géographie courante comme dérivations externes, et recalcul de contrôle par le graphe de filiation (Q13). Dépend de : T2.1, T2.2.

## J3 — Tranche 1 : tuiles et carte

- [ ] **T3.1** Publication de tuiles, avec les trois contrôles d'export de l'ADR 0004. Dépend de : J2.
- [ ] **T3.2** Population en cercles proportionnels, placés sur le centre du plus grand cercle inscrit dans le contour de chaque commune (géométrie dérivée, §6.1). Dépend de : T3.1.
- [ ] **T3.3** Choroplèthe du taux d'évolution annuel moyen entre deux dates espacées d'au moins cinq ans (observation dérivée interne, §8.4) ; palette divergente centrée sur 0, seuils fixés dans la fiche de la variable (`docs/politique-editoriale.md`, §5.4). Dépend de : T3.1.
- [ ] **T3.4** Mention, dans l'interface, que les valeurs passées portent sur le territoire des communes actuelles. Dépend de : T3.2.
- [ ] **T3.5** **Lien vers le code source dans l'interface.** Le JavaScript envoyé au navigateur est généralement considéré comme une distribution du programme : l'application indique où trouver son code source (ADR 0011). Origine : `docs/adr/0011-licence-du-code.md`.

## Non priorisé

Tâches identifiées mais pas encore engagées. Chaque entrée renvoie au document qui l'a fait naître.

### Géométries historiques

Origine : `docs/recherches/sources-geometries-historiques.md`.

- [ ] **Évaluer COMMUNES v2 (CC BY 4.0)** : couverture, précision, traitement de l'Alsace-Moselle, et possibilité juridique de la réutiliser alors que la v6 est passée en CC BY-NC 4.0. La v6 elle-même ne peut pas être importée : une source NC est citable, jamais importée (`docs/politique-editoriale.md`, §4.4).
- [ ] **Préparer un message de prise de contact** avec l'équipe du projet COMMUNES (ANR COMMUNE-HISDBD).
- [ ] **Reconstitution des géométries historiques**, piste de repli : produire des géométries **dérivées** (§6.1 et §8.4 du modèle) à partir d'ADMIN EXPRESS (communes associées ou déléguées), des préfixes de section du cadastre et des mouvements du COG, en assumant qu'elles portent les limites actuelles.

### Licences et contributions

Origine : `docs/adr/0011-licence-du-code.md`.

- [ ] **Conditions de contribution du code.** Déclencheur : *avant de fusionner la première contribution extérieure.* Réexaminer des conditions de contribution qui n'autorisent un changement de licence que vers une autre licence libre, alignées sur celles prévues pour les données (`docs/politique-editoriale.md`, §4.2). D'ici là, les contributions sont acceptées sous DCO.
