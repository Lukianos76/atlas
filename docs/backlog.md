# Backlog

Tâches identifiées mais pas encore engagées. Chaque entrée renvoie au document qui l'a fait naître.

## Géométries historiques

Origine : `docs/recherches/sources-geometries-historiques.md`.

- [ ] **Évaluer COMMUNES v2 (CC BY 4.0)** : couverture, précision, traitement de l'Alsace-Moselle, et possibilité juridique de la réutiliser alors que la v6 est passée en CC BY-NC 4.0. La v6 elle-même ne peut pas être importée : une source NC est citable, jamais importée (`docs/politique-editoriale.md`, §4.4).
- [ ] **Préparer un message de prise de contact** avec l'équipe du projet COMMUNES (ANR COMMUNE-HISDBD).
- [ ] **Reconstitution des géométries historiques**, piste de repli : produire des géométries **dérivées** (§6.1 et §8.4 du modèle) à partir d'ADMIN EXPRESS (communes associées ou déléguées), des préfixes de section du cadastre et des mouvements du COG, en assumant qu'elles portent les limites actuelles.

## Licences et contributions

Origine : `docs/adr/0011-licence-du-code.md`.

- [ ] **Tranche 1 : lien vers le code source dans l'interface.** Le JavaScript envoyé au navigateur est généralement considéré comme une distribution du programme : l'application indique où trouver son code source (ADR 0011).
- [ ] **Conditions de contribution du code.** Déclencheur : *avant de fusionner la première contribution extérieure.* Réexaminer des conditions de contribution qui n'autorisent un changement de licence que vers une autre licence libre, alignées sur celles prévues pour les données (`docs/politique-editoriale.md`, §4.2). D'ici là, les contributions sont acceptées sous DCO.

## Base de référence

Origine : `docs/schema.md`, section 4.

- [ ] **Sauvegarde hors de la machine de la base de référence.** Prérequis au premier import de la tranche 1 : la base doit être sauvegardée hors de la machine dès le premier lot validé. Ses identifiants internes, publiés dans les tuiles et les fichiers de valeurs, ne sont jamais réattribués : la base ne peut pas être reconstruite par réimport.
- [ ] **Identifiants du superutilisateur hors du `.env`.** Prérequis au premier import de la tranche 1 (`docs/schema.md`, §5.13) : le `.env` lu par les pipelines et par Claude Code ne contient plus que les identifiants d'un rôle d'import. Le superutilisateur et `atlas_owner` sont saisis de façon interactive par `scripts/db-ref-migrate.sh`, parce qu'un superutilisateur peut prendre n'importe quel rôle et contourner la séparation des droits.
- [ ] **Script de création des rôles de connexion.** Un rôle par contributeur, membre d'`atlas_import` ou d'`atlas_review`, avec un mot de passe demandé de façon interactive et jamais écrit dans un fichier du dépôt ; enregistrement du contributeur correspondant (`contributor.db_role`).
