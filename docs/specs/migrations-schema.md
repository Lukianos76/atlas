# Migrations du schéma et tests de violation

- **Statut** : proposé
- **Date** : 2026-10-18
- **Phase** : Phase 1. Tranche 1 : le Bas-Rhin depuis 1968, section « Base »
- **Documents de référence** : `docs/schema.md` (§3, §5.1 à §5.13, §6, §12), ADR 0003, ADR 0010, `docs/modele-donnees.md` §10.5, `docs/glossaire.md`

## Objectif

Traduire `docs/schema.md` §5.1 à §5.13 en migrations dbmate (SQL pur, `migrate:down` vide), les appliquer à la base de développement, et prouver par des tests de violation que la base refuse ce que le schéma interdit. Schéma seul : aucune donnée.

## Contexte

- `db/migrations/` ne contient que la migration initiale, vide (`20261017000000_init.sql`).
- `docs/schema.md` §12 consigne des essais ponctuels, non versionnés : « les migrations reprendront ces constructions, et `check.sh` les éprouvera ».
- `check.sh --db` applique aujourd'hui les migrations à une base jetable `atlas_check` et vérifie `dbmate status`. Il n'exécute aucun test.
- Règle 6 : migrations immuables, en avant uniquement. Règle 5 : identifiants en anglais selon le glossaire, dont la version 2 (validée le 2026-10-17) reprend les termes du §10 du schéma.

## Critères d'acceptation

Chaque critère est éprouvé par `bash check.sh --db`, sur la base jetable.

- [ ] Les migrations s'appliquent de bout en bout sur une base vide et `dbmate status --exit-code` réussit.
- [ ] Les extensions `postgis` et `btree_gist` sont présentes.
- [ ] Les rôles de groupe `atlas_owner`, `atlas_import` et `atlas_review` existent, sans `LOGIN`. Ni `atlas_import` ni `atlas_review` n'a de droit `DELETE` ni `TRUNCATE`, ni de droit de création sur le schéma ; `atlas_review` inclut les droits d'`atlas_import` ; un rôle de connexion d'essai ne peut être membre que d'un seul rôle de groupe.
- [ ] Chaque table du §5 existe avec les colonnes et contraintes du schéma, comparées au catalogue PostgreSQL (méthode retenue en D-b : fichier versionné des objets attendus).
- [ ] Chacun des six `CHECK` de période (§3.2) refuse une ligne qui le viole et accepte une ligne conforme.
- [ ] Chacune des quatre clés étrangères composites vers `historical_date` (§3.3) refuse une borne qui diffère de la date historique ; fin inconnue acceptée (§12, essais 3a à 3e).
- [ ] P7 : `DELETE` et `TRUNCATE` sont refusés sur chaque table, y compris pour le propriétaire, sauf les tables de liaison des citations dans une transaction révisée (§5.3). L'autre exception du §1, la procédure d'activation des partitions (§6), est hors périmètre.
- [ ] La mise à jour interdite d'`entity` et d'`event` est refusée.
- [ ] D3 : une ligne hors lot sans citation est refusée au commit ; acceptée si la citation est dans la même transaction ; une ligne de lot est exemptée (§12, essais 2b à 2e).
- [ ] N10 : un événement sans assertion de date citée est refusé, quel que soit le statut de révision.
- [ ] A11 et N11 : un triplet d'identifiant en double est refusé pour les statuts `proposed`, `validated` et `contested` ; un code `withdrawn` libère le triplet.
- [ ] Garde des statuts (§5.13) : chaque ligne du tableau de transitions est éprouvée avec un rôle de connexion d'essai membre d'`atlas_import` (refus) et d'`atlas_review` (accord) ; essais 4a à 4d du §12 rejoués : passage à `validated` refusé (4a), insertion directe dans `revision` refusée (4b), `SET ROLE` et `SET SESSION AUTHORIZATION` refusés (4c), validation par un membre d'`atlas_review` acceptée avec le contributeur retrouvé par `current_user` (4d). Les essais 4e et 5 (superutilisateur, `pg_hba`) sont hors périmètre.
- [ ] Le noyau temporel renvoie `empty`, sans erreur, quand les bornes se croisent (§12, essai 3e).
- [ ] Les tests échouent si la version majeure de PostgreSQL diffère de celle de l'image de `compose.yaml` (`postgis/postgis:18-3.6`, §12).
- [ ] Les rôles de connexion d'essai sont supprimés en fin de test, y compris après un échec (`trap`) ; une relance après interruption réussit (idempotence).
- [ ] A13 : un lot dont le vérificateur n'est pas un contributeur `human`, ou est le responsable du lot, est refusé.
- [ ] `observation` n'a que la partition `observation_default` ; la table partitionnée et ses triggers de refus sont en place (§6, état initial).
- [ ] Chaque test de violation a son pendant conforme : remplacer l'instruction fautive par une instruction conforme fait échouer le test de refus, et l'inverse.

## Hors périmètre

- Toute donnée, y compris les référentiels : aucun import.
- La base de référence et `scripts/db-ref-migrate.sh` (tâche distincte, depuis `main`).
- Les rôles de connexion réels et leurs mots de passe (tâche « Rôles de connexion »). Seuls des rôles d'essai existent, dans les tests.
- Les identifiants du superutilisateur hors du `.env`.
- Le §11 du schéma (hors tranche 1).
- L'activation du partitionnement par variable (§6) et ses essais 1a à 1c : voir Questions ouvertes.

## Données et sources

Aucune (schéma seul). Aucune entrée à ajouter à `docs/data-sources.md`.

## Décisions à prendre

Toutes tranchées par le mainteneur le 2026-10-18 (commentaire de PR) : les recommandations sont retenues.

- **D-a. Découpage des migrations.** Retenu : plusieurs migrations ordonnées par dépendance (extensions et rôles ; référentiels et sources ; temps et période ; assertions ; événements ; observations ; lots et révisions ; garde des statuts et droits). Écarté : une seule migration, plus difficile à relire.
- **D-b. Liste des objets attendus.** Retenu : un fichier versionné, dérivé du §5, que le test compare au catalogue PostgreSQL.
- **D-c. Outil des tests.** Retenu : fichiers SQL lancés par `psql` dans le conteneur, sans dépendance nouvelle.
- **D-d. Rôles de connexion d'essai.** Retenu : créés par le script de test, avec les mots de passe connus de `.env.example` (§5.13), et supprimés ensuite ; jamais par migration (rien de secret dans git, et ils n'existent pas sur la base de référence).
- **D-e. Lancement.** Retenu : dans `check.sh --db`, sur la base jetable `atlas_check`, après les migrations.

## Questions ouvertes

Aucune en attente.

Résolue le 2026-10-18 (recommandation retenue) : les essais 1a à 1c du §12 (partitionnement) sont laissés à la future migration d'activation, hors périmètre.
