# Schéma logique de la base (tranche 1)

> **Statut** : version 1 (octobre 2026), soumise à validation. Décisions D1 à D5, réponses A1 à A21 et points N1 à N11 validés par le mainteneur le 2026-10-17, ainsi que les corrections du même jour : séparation des rôles et sa limite assumée (§5.13), immutabilité des contenus volumineux (§5.4, §5.11), imports rejouables (§5.8, §5.10). Révisions issues de la traduction en migrations validées le même jour (§8.5). Les essais sur la base de développement sont consignés en section 12.
> **Portée** : conception **logique** du schéma PostgreSQL 18 + PostGIS pour le seul périmètre de la tranche 1 (`docs/modele-donnees.md`, §14.2) : population communale du Bas-Rhin, géographie communale du COG et son historique depuis 1968, géographie courante d'ADMIN EXPRESS, séries de l'INSEE en géographie courante (dérivations externes) et recalcul par le graphe de filiation. Ce document ne contient aucun SQL de migration : les migrations (ADR 0010) en découleront.
> **Références** : modèle de données (v3.1), ADR 0003, 0004, 0009 et 0010, glossaire (v2), politique éditoriale (v1). En cas d'écart, ces documents font foi ; les révisions qu'il a entraînées sont regroupées en section 8.

---

## 1. Conventions

- **Identifiants** en anglais, `snake_case`, selon `docs/glossaire.md`. Les termes absents du glossaire sont proposés en section 10 et ne valent qu'après validation.
- **Tables de type d'assertion** suffixées `_assertion` (`name_assertion`, `geometry_assertion`…), pour éviter des tables nommées comme un type PostGIS (`geometry`) ou un mot courant (`name`).
- **Vocabulaires fermés** du modèle (certitude, statut de révision, nature des bornes, nature d'une observation, rôle de participation, statut de lot, type de source…) : types `enum`. Ajouter une valeur (`ALTER TYPE … ADD VALUE`) reste compatible avec des migrations en avant uniquement ; une valeur n'est jamais retirée.
- **Vocabulaires ouverts**, que le modèle dit extensibles (catégories d'entité, types de relation, types d'événement, référentiels) : tables de référence.
- **Valeurs de données non traduites** (glossaire, §1) : statuts juridiques, noms de niveaux, types d'objet du COG (`COM`, `COMA`, `COMD`) restent des valeurs `text`.
- **Rien n'est effacé** (P7). Un trigger `BEFORE DELETE` refuse toute suppression, sur toutes les tables, un trigger `BEFORE TRUNCATE` refuse toute troncature (le propriétaire et le superutilisateur ne sont pas arrêtés par les droits), et les droits `DELETE` et `TRUNCATE` ne sont pas accordés. Seules exceptions : les tables de liaison des citations, dans une transaction révisée (§5.3), et la procédure d'activation des partitions (§6).
- **Principe de stockage** (réponses du mainteneur, §7) : si le modèle prévoit qu'un fait puisse être contesté ou daté, c'est une **assertion** ; ce qui peut se **déduire** n'est pas stocké en double.
- **Contenus volumineux immuables** : un contenu volumineux (géométrie, et tout contenu de taille comparable à venir : zones floues, récits) ne se corrige jamais sur place. Une correction retire l'assertion et en crée une nouvelle, comme pour les citations ; les instantanés de révision le référencent sans le recopier (§5.11).
- **Séparation des rôles** : l'identité d'un contributeur est celle du rôle PostgreSQL de connexion (`current_user`), jamais une valeur déclarée ; seul le rôle de vérification valide (§5.13).

---

## 2. Décisions de conception

### D1. Assertions : tronc commun et tables par type

| Option | Conséquences |
|---|---|
| A. Table générique, contenu `jsonb` | Un seul endroit pour période, citations et révisions ; nouveau type sans migration. Mais contenu sans typage ni clé étrangère, pas de contrainte sur les codes, pas de colonne PostGIS, volume prohibitif pour les observations. |
| B. Une table par type, colonnes communes recopiées | Typage et contraintes par type. Mais citations et révisions polymorphes, `UNION` de toutes les tables pour lire une entité, tronc dupliqué à tenir identique. |
| **C. Hybride** | Table `assertion` pour le tronc commun ; une table par type, dont la clé primaire est aussi clé étrangère vers `assertion (id, assertion_type)`. Une seule clé étrangère pour les citations et les révisions, contenu typé, nouveau type = nouvelle table. Coût : une jointure par lecture ; les contraintes qui mêlent contenu et période recopient la période dans la table du type. |

**Décision : C.** Les **observations** font exception : elles ont leur propre table, colonnes communes incluses, à cause de leur volume, de la citation mutualisée par lot (ADR 0003) et du partitionnement (D5).

### D2. Type des identifiants internes

| Option | Conséquences |
|---|---|
| **A. `integer` / `bigint`** | `integer` pour les entités et les événements, `bigint` pour les tables volumineuses (assertions, observations, citations, révisions), petits entiers pour les référentiels. L'identifiant d'entité est l'identifiant de la feature MVT (`promoteId`, ADR 0004) et un INT32 dans le Parquet (ADR 0009), lu comme un `number` en JavaScript. |
| B. `bigint` partout | Uniforme, mais un INT64 Parquet est lu comme un `BigInt` en JavaScript : conversion à chaque jointure. |
| C. UUID v7 | Indépendant de la base, mais lourd dans les tuiles et le Parquet, et inutilisable comme identifiant entier de Tippecanoe. |
| D. UUID et entier de publication | Table de correspondance à maintenir et à publier. |

**Décision : A.** Toutes les colonnes d'identité sont `GENERATED ALWAYS AS IDENTITY`. Règles complémentaires en section 4.

### D3. Garantie de P3 hors des lots

| Option | Conséquences |
|---|---|
| **A. Trigger de contrainte différé** | Contrôle au commit d'au moins une citation, fidèle au 1..n du modèle, structurel. L'erreur n'apparaît qu'au commit. |
| B. Citation principale `NOT NULL` | Déclaratif, mais asymétrie entre la première citation et les suivantes. |
| C. Fonctions d'écriture `SECURITY DEFINER` | La garantie dépend des droits, pas du schéma. |
| D. Lot d'un seul élément | La sémantique d'un lot ne convient pas à une saisie isolée. |

**Décision : A**, avec une révision proposée de l'ADR 0003 (§8.1). Précisions du mainteneur :
- un `CHECK` ne lit pas d'autres tables. Pour une observation, seul le cas « lot **et** localisateur » est un `CHECK` ;
- les deux autres cas (au moins une citation liée ; dérivation interne avec au moins une entrée) passent par le trigger de contrainte différé, déclaré `WHEN (NEW.import_batch_id IS NULL)` : les imports en masse ne le paient pas.

### D4. Révisions et temps de transaction

| Option | Conséquences |
|---|---|
| **A. Journal en ajout seul** | Une table `revision` avec l'instantané de l'état résultant ; l'état courant est recopié dans les tables d'assertions ; une seule table à lire pour « l'atlas au temps R ». |
| B. Versions typées | Historique typé, mais identité et version à séparer dans chaque table, et toutes les clés étrangères en dépendent. |
| C. Modèle littéral (`previous_content` seul) | Écriture simple ; reconstitution au temps R lente et fragile. |

**Décision : A**, strictement en ajout seul. Précisions du mainteneur :
- la révision ne stocke que `recorded_at`, **sans borne supérieure** à mettre à jour. La période de transaction se déduit de la révision suivante, par une vue appuyée sur l'index `(assertion_id, recorded_at, id)` (§5.12) ;
- le trigger de révision **ne s'exécute pas ligne par ligne** pour les observations importées par lot : la révision du lot vaut pour toutes ses observations (ADR 0003). Voir §5.10 et §5.11.

### D5. Partitionnement des observations

| Option | Conséquences |
|---|---|
| A. Rien en tranche 1 | La conversion ultérieure réécrit la table et change les clés de toutes les tables qui la référencent. |
| B. Clés compatibles seulement | Conversion par copie, mais rien n'empêche entre-temps une contrainte incompatible. |
| **C. Partitionnement déclaré** | `PARTITION BY LIST (variable_id)`, une seule partition `DEFAULT` en tranche 1. PostgreSQL impose dès maintenant la forme des clés. |

**Décision : C.** La clé `variable_id` suit les accès réels : un lot, une publication et un fichier de valeurs portent sur une variable (ADR 0009). La procédure d'activation est décrite en section 6.

---

## 3. Le motif de période

Commun à tout objet daté (ADR 0003). Il est décrit une fois et repris dans les tables par la mention « motif de période ». Dans `observation`, ses colonnes sont préfixées `reference_` (période de référence, réponse A5).

### 3.1 Colonnes

| Colonne | Type | Contraintes |
|---|---|---|
| `start_kind` | enum `start_kind` (`dated`, `unknown`) | `NOT NULL`, sans valeur par défaut |
| `start_earliest` | `int4` (jour julien) | voir 3.2 |
| `start_latest` | `int4` | `NOT NULL` (date ou première attestation) |
| `start_date_id` | `bigint` → `historical_date` | `NOT NULL` |
| `end_kind` | enum `end_kind` (`dated`, `ongoing`, `unknown`) | `NOT NULL`, sans valeur par défaut |
| `end_earliest` | `int4` | voir 3.2 |
| `end_latest` | `int4` | voir 3.2 |
| `end_date_id` | `bigint` → `historical_date` | `NULL` seulement si `end_kind = 'ongoing'` |
| `end_latest_dated` | `int4`, générée : `CASE WHEN end_kind = 'dated' THEN end_latest END` | sert à la clé étrangère de 3.3 |
| `core_range` | `int4range`, générée | noyau `[start_latest, end_earliest[` ; **vide** si `end_earliest <= start_latest` (expression `CASE`, sans erreur) |
| `max_range` | `int4range`, générée | extension maximale `[start_earliest, end_latest[`, borne `NULL` = non bornée |

Une période est semi-ouverte (`[début, fin[`, modèle §3.2) : la fin est le premier jour où le fait n'est plus vrai.

### 3.2 Contraintes `CHECK` (ADR 0003)

- `start_kind = 'dated'` : `start_earliest` renseigné et `start_earliest <= start_latest`.
- `start_kind = 'unknown'` : `start_earliest IS NULL`, `start_latest` = première attestation. (Une borne au plus tôt sur un début inconnu, venant d'une autre source, est reportée : §9, N2.)
- `end_kind = 'dated'` : `end_earliest` et `end_latest` renseignés, `end_earliest <= end_latest`.
- `end_kind = 'ongoing'` : `end_earliest`, `end_latest` et `end_date_id` `NULL`. `ongoing` est une affirmation citée, jamais un défaut.
- `end_kind = 'unknown'` : `end_earliest` renseigné (dernière attestation) ; `end_latest` renseigné seulement si une source atteste la disparition (règle d'import et de relecture, non vérifiable par la base), et alors `end_latest >= end_earliest`.
- Cohérence globale : `start_earliest < end_latest` quand les deux sont renseignés.

### 3.3 Lien avec `historical_date`

Les bornes normalisées sont **recopiées** dans la table qui porte la période, pour être indexées et contraintes. Leur accord avec la date historique est garanti par des clés étrangères composites (`MATCH SIMPLE` : une colonne `NULL` désactive la clé concernée) :

| Clé étrangère | Vers | Couvre |
|---|---|---|
| `(start_date_id, start_latest)` | `historical_date (id, latest)` | tout début |
| `(start_date_id, start_earliest)` | `historical_date (id, earliest)` | début daté |
| `(end_date_id, end_earliest)` | `historical_date (id, earliest)` | fin datée ou inconnue |
| `(end_date_id, end_latest_dated)` | `historical_date (id, latest)` | fin datée |

Pour une fin inconnue, la date qui atteste la disparition (`end_latest`) est appuyée par une citation de rôle `date` ; elle n'a pas de lien propre vers `historical_date` (§9, N2). La clé étrangère sur la colonne générée stockée `end_latest_dated` a été vérifiée en base de développement (§12, essai 3).

### 3.4 Index

GiST sur `core_range` pour les requêtes « valide à la date T » ; `max_range` n'est indexée que là où les transitions floues sont contrôlées (aucune en tranche 1 : les dates du COG sont exactes).

---

## 4. Identifiants

- Les identifiants internes ne sont **jamais réutilisés ni réattribués**, y compris quand l'objet est retiré : un objet retiré garde son identifiant (P7), et une séquence d'identité ne revient jamais en arrière.
- L'identifiant d'entité est **permanent** (modèle §4.1) et publié : il est l'identifiant des features dans les tuiles et la clé de jointure des fichiers de valeurs. Une publication citée ne reste vérifiable que si ces identifiants ne changent jamais.
- Les identifiants dépendent de la **base de référence** : elle ne doit jamais être reconstruite par réimport. Elle est **sauvegardée hors de la machine dès le premier lot validé** ; la mise en place de cette sauvegarde est un prérequis au premier import de la tranche 1 (`docs/backlog.md`).
- La base de développement attribue ses propres identifiants : aucun test ni extrait ne doit en dépendre.

---

## 5. Tables

Notation : `→ t` désigne une clé étrangère vers la table `t`. Sauf mention contraire, les colonnes sont `NOT NULL`.

### 5.1 Référentiels

**`entity_category`** : taxonomie ouverte et hiérarchique (modèle §4.2).

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `smallint` identité | clé primaire |
| `parent_id` | `smallint` → `entity_category` | `NULL` pour une catégorie de premier niveau |
| `code` | `text` | `UNIQUE` |
| `label` | `text` | libellé français |

Catégories de premier niveau (codes proposés en section 10) : `political`, `administrative`, `statistical`, `cultural`, `natural`, `place`, et **`organization`** (réponse A10), pour l'INSEE et les institutions comparables. La taxonomie étant ouverte, cet ajout est une donnée et ne révise pas le modèle.

**`contributor`**

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire |
| `contributor_kind` | enum (`human`, `agent`) | |
| `display_name` | `text` | |
| `db_role` | `name` | `UNIQUE` ; rôle PostgreSQL de connexion du contributeur (§5.13) |
| | | `UNIQUE (id, contributor_kind)`, cible de la clé de `import_batch` (A13) |

Un contributeur a exactement un rôle de connexion, et un rôle de connexion exactement un contributeur. Les triggers retrouvent le contributeur par `db_role = current_user` ; un rôle sans contributeur ne peut rien écrire.

**`entity`** : identité nue (P2).

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire |
| `entity_category_id` | `smallint` → `entity_category` | |

Aucune période : l'existence se **déduit** (réponse A1, vue `entity_existence`, §5.12). Aucune mise à jour (trigger `BEFORE UPDATE`).

**`division_system`**

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `smallint` identité | clé primaire |
| `authority_entity_id` | `integer` → `entity` | autorité du système (modèle §4.3) |
| `label` | `text` | libellé technique, non affiché comme un fait |

Sa validité est une assertion (`system_validity_assertion`, réponse A16). C'est d'elle, et non d'une copie, que se lit l'autorité des appartenances (A15).

**`level`**

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `smallint` identité | clé primaire |
| `division_system_id` | `smallint` → `division_system` | |
| `label` | `text` | valeur de données non traduite (« commune », « département ») |
| `rank` | `smallint` | ordre dans le système, du plus grand au plus fin |
| | | `UNIQUE (division_system_id, label)` |

**`registry`** : référentiels d'identifiants (modèle §5.3).

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `smallint` identité | clé primaire |
| `code` | `text` | `UNIQUE` (« INSEE COG ») |
| `authority_entity_id` | `integer` → `entity` | `NULL` ; l'organisation qui tient le référentiel |

**`relation_type`**, **`relation_subtype`**, **`event_type`** : tables de référence `(id smallint identité, code text UNIQUE)` ; `relation_subtype` porte en plus `relation_type_id`. Codes de la tranche 1 : `continuation_of`, avec les sous-types `restoration` et `usage_continuity` ; types d'événement du glossaire (§5).

**Chargement** : les codes de la tranche 1 (catégories de premier niveau, types et sous-types de relation, types d'événement) sont chargés par la migration des référentiels. Libellés des catégories de premier niveau (validés le 2026-10-17) : `political` politique, `administrative` administrative, `statistical` statistique, `cultural` culturelle, `natural` naturelle, `place` lieu, `organization` organisation.

**`historical_date`** : la date telle que la source l'écrit (modèle §3.1). Immuable.

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `bigint` identité | clé primaire |
| `original_expression` | `text` | |
| `source_calendar` | enum | valeurs proposées en section 10 |
| `granularity` | enum | `day`, `month`, `year`, `decade`, `century`, `millennium` (proposées) |
| `qualifier` | enum (`exact`, `approximate`, `before`, `after`, `presumed`) | |
| `earliest`, `latest` | `int4` | `earliest <= latest` |
| `conversion_rule` | `text` | `NULL` si aucune conversion de calendrier ; sinon la règle appliquée (modèle §3.1) |
| | | `UNIQUE (id, earliest)`, `UNIQUE (id, latest)` : cibles des clés de 3.3 ; `UNIQUE (id, earliest, latest)` : cible de `event_date_assertion` (5.5) |

Une même date est partagée par toutes les périodes qui la citent (date d'effet d'un mouvement du COG, date d'un recensement).

### 5.2 Sources

**`source_work`** (modèle §9.1)

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire |
| `source_type` | enum (`primary`, `secondary`, `derived`) | |
| `title` | `text` | |
| `authors` | `text[]` | `NULL` |
| `publisher` | `text` | `NULL` |
| `publication_date_id` | `bigint` → `historical_date` | `NULL` |
| `version`, `edition`, `vintage` | `text` | `NULL` ; `vintage` obligatoire en pratique pour un jeu de données révisé (politique §3.5), contrôlé par le lot |
| `persistent_ids` | `jsonb` | `NULL` ; objet `{schéma: valeur}` (DOI, ISBN, ARK, cote) |
| `license` | `text` | identifiant SPDX, ou valeur convenue pour le domaine public |
| `license_archived_copy` | `text` | `NULL` ; copie archivée de la page de licence, exigée au premier usage d'une licence hors de la liste acceptée (politique §4.3) |
| `language` | `text` | BCP 47 |
| `parent_work_id` | `integer` → `source_work` | `NULL` ; œuvre qui contient celle-ci |

**`citation`** (modèle §9.2) : immuable (trigger `BEFORE UPDATE`), **partageable** entre plusieurs assertions (réponse A9). Le rôle est porté par les tables de liaison.

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `bigint` identité | clé primaire |
| `source_work_id` | `integer` → `source_work` | index |
| `locator` | `text` | `CHECK (locator <> '')` |
| `accessed_url` | `text` | `NULL` |
| `archived_copy` | `text` | `NULL` |
| `accessed_on` | `date` | `NULL` ; date moderne, le type `date` suffit |
| `excerpt` | `text` | `NULL` |

Corriger une citation, c'est en créer une nouvelle et changer le lien dans une révision de l'assertion.

### 5.3 Tronc commun des assertions

**`assertion`**

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `bigint` identité | clé primaire |
| `assertion_type` | enum `assertion_type` | une valeur par table de type (5.4 à 5.6) |
| `subject_entity_id` | `integer` → `entity` | `NULL` |
| `subject_event_id` | `integer` → `event` | `NULL` |
| `subject_division_system_id` | `smallint` → `division_system` | `NULL` |
| motif de période (§3) | | **`NULL` en bloc** pour les assertions dont le sujet est un événement (§9, N1) |
| `authority_entity_id` | `integer` → `entity` | `NULL` ; obligatoire selon le type (contrôle différé ci-dessous) |
| `certainty` | enum (`established`, `probable`, `possible`, `conjectural`) | sans valeur par défaut |
| `margin` | `numeric` | `NULL` |
| `opening_event_id`, `closing_event_id` | `integer` → `event` | `NULL` |
| `review_status` | enum (`proposed`, `validated`, `contested`, `withdrawn`) | état courant, recopié de la dernière révision |

Contraintes :
- `CHECK (num_nonnulls(subject_entity_id, subject_event_id, subject_division_system_id) = 1)` ;
- `CHECK` d'accord entre le type et le sujet : sujet événement pour `participation`, `transfer`, `event_type` et `event_date` ; sujet système pour `system_validity` ; sujet entité pour les autres ;
- `CHECK` : le motif de période est entièrement `NULL` si et seulement si le sujet est un événement ;
- `UNIQUE (id, assertion_type)`, cible des tables de type ;
- `UNIQUE (id, assertion_type, subject_entity_id, core_range, review_status)`, cible de la copie de `external_id_assertion` (5.4).

Index : `(subject_entity_id, assertion_type)`, `(subject_event_id, assertion_type)`, `(subject_division_system_id)`, `(authority_entity_id)`, GiST `(core_range)`.

**Trigger de validation différé** (`DEFERRABLE INITIALLY DEFERRED`), sur `assertion` et sur chaque table de type, au commit :
- l'assertion a exactement une ligne dans la table de son type ;
- **P3** : au moins une ligne dans `assertion_citation` ;
- autorité selon le type (modèle §5.6) : obligatoire pour `legal_status` et pour un nom `official` ; **`NULL`** pour `system_membership`, dont l'autorité se lit sur le système (A15) ;
- règles propres aux types (5.4 à 5.6).

**`assertion_citation`**

| Colonne | Type | Contraintes |
|---|---|---|
| `assertion_id` | `bigint` → `assertion` | |
| `citation_id` | `bigint` → `citation` | index |
| `citation_role` | enum `citation_role` | `value`, `date`, `geometry`, `share` (proposés) |
| | | clé primaire `(assertion_id, citation_id, citation_role)` |

Une suppression de lien n'est admise que dans une transaction révisée (§5.11), c'est-à-dire une transaction qui renseigne le motif (`SET LOCAL atlas.reason`) ; le trigger différé vérifie alors qu'il reste au moins une citation, et la révision `correct` de l'assertion porte ce motif. Seul `assertion_citation` admet cette exception ; `observation_citation` n'en a pas besoin, une observation corrigée recevant une nouvelle citation sans perdre l'ancienne.

### 5.4 Assertions sur les entités

Chaque table de type a pour clé primaire `id bigint`, une colonne `assertion_type` fixée par `CHECK`, et la clé étrangère `(id, assertion_type) → assertion (id, assertion_type)`.

**`name_assertion`** (modèle §5.2)

| Colonne | Type | Contraintes |
|---|---|---|
| `text` | `text` | index |
| `language` | `text` | BCP 47 |
| `script` | `text` | ISO 15924 |
| `transliteration` | `text` | `NULL` |
| `name_type` | enum (`official`, `endonym`, `exonym`, `historical`, `common`, `abbreviated`) | |

**`external_id_assertion`** (modèle §5.3)

| Colonne | Type | Contraintes |
|---|---|---|
| `registry_id` | `smallint` → `registry` | |
| `object_type` | `text` | `NULL` ; vocabulaire du référentiel (`COM`, `COMA`, `COMD`) |
| `code` | `text` | |
| `subject_entity_id`, `core_range`, `review_status` | copies | clé étrangère composite `(id, assertion_type, subject_entity_id, core_range, review_status) → assertion`, `ON UPDATE CASCADE` |

Unicité du triplet à une date : **refus** (réponse A11), le référentiel faisant autorité sur ses propres codes :
`EXCLUDE USING gist (registry_id WITH =, coalesce(object_type, '') WITH =, code WITH =, core_range WITH &&, subject_entity_id WITH <>) WHERE (review_status <> 'withdrawn')` (extension `btree_gist`). Le cas d'Annecy (74010 en `COM` pour E7 et en `COMD` pour E1, modèle §11.2) passe, puisque les types d'objet diffèrent. Index : `(registry_id, object_type, code)`.

**`legal_status_assertion`** (modèle §5.4) : `legal_status text` (valeur non traduite). Autorité obligatoire.

**`system_membership_assertion`** (modèle §4.3)

| Colonne | Type | Contraintes |
|---|---|---|
| `level_id` | `smallint` → `level` | index ; le système se lit sur le niveau |
| `parent_entity_id` | `integer` → `entity` | `NULL` au niveau le plus haut ; index |

**`relation_assertion`** (modèle §5.5)

| Colonne | Type | Contraintes |
|---|---|---|
| `relation_type_id` | `smallint` → `relation_type` | |
| `relation_subtype_id` | `smallint` → `relation_subtype` | `NULL` ; doit appartenir au type (clé composite) |
| `target_entity_id` | `integer` → `entity` | index |

La relation `recognizes`, qui vise une assertion, n'entre pas dans la tranche 1 : une colonne `target_assertion_id` lui sera ajoutée.

**`geometry_assertion`** (modèle §6.1)

| Colonne | Type | Contraintes |
|---|---|---|
| `shape` | `geometry(Geometry, 4326)` | `CHECK` sur le type : polygone, multipolygone, point, ligne ; index GiST |
| `spatial_accuracy` | `numeric` | `NULL` ; en mètres |
| `resolution` | `integer` | `NULL` ; dénominateur d'échelle |
| `method` | enum (`official_survey`, `digitization`, `reconstruction`, `derivation`, `estimate`) | |
| `source_crs` | `text` | système de coordonnées de la source (« EPSG:2154 » pour ADMIN EXPRESS), réponse A21 |
| `parent_geometry_id` | `bigint` → `geometry_assertion` | `NULL` |

Stockage en WGS 84 (A21) ; les surfaces se calculent en `geography` ou dans une projection adaptée.

**Contenu immuable** (correction du 2026-10-17) : un trigger `BEFORE UPDATE` refuse toute modification de `geometry_assertion`. Une géométrie erronée se corrige en **retirant** l'assertion et en **créant** une nouvelle assertion, avec sa propre géométrie et ses citations ; le motif du retrait nomme la nouvelle assertion. Le tronc commun reste modifiable selon les règles de révision : clore la période d'une géométrie quand une limite change (modèle §6.2) ne touche pas au contenu. La validité OGC des géométries est un **contrôle automatique du lot**, pas un `CHECK` : corriger une géométrie de la source serait la modifier. Zones floues et géométries dérivées de plusieurs parents : hors tranche 1 (section 11). Le point des cercles proportionnels n'est **pas stocké** (A17, §8.2).

### 5.5 Événements et assertions sur les événements

**`event`** : identité nue (réponse A3).

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire |

Aucune mise à jour. **Trigger de contrainte différé** : un événement a au moins une assertion `event_date` (réponse A4) ; celle-ci étant une assertion, elle est citée (P3). L'événement n'a pas de citation propre.

**`event_type_assertion`** : `event_type_id smallint → event_type`. Le type est une assertion pour admettre plus tard des types concurrents (Q8).

**`event_date_assertion`** (réponse A3, Q12) : la date est le **contenu** de l'assertion, pas une période de validité (§9, N1).

| Colonne | Type | Contraintes |
|---|---|---|
| `event_date_kind` | enum (`effective`, `act`, `signature`, `entry_into_force`) | |
| `date_id` | `bigint` → `historical_date` | |
| `earliest`, `latest` | `int4` | copies ; clé composite `(date_id, earliest, latest)` → `historical_date (id, earliest, latest)` ; index `(latest)` |
| `end_date_id`, `end_earliest`, `end_latest` | idem | `NULL` ; fin d'un processus long (modèle §7.1) |

La tranche 1 n'emploie que `effective` (date d'effet du COG) et `act` (date de l'acte).

**`participation_assertion`** (modèle §7.1, réponse A2)

| Colonne | Type | Contraintes |
|---|---|---|
| `entity_id` | `integer` → `entity` | index `(entity_id, role)` |
| `role` | enum (`created`, `dissolved`, `affected`, `actor`) | |

**`transfer_assertion`** (modèle §7.2)

| Colonne | Type | Contraintes |
|---|---|---|
| `from_entity_id`, `from_level_id` | `integer` → `entity`, `smallint` → `level` | index `(from_entity_id)` |
| `to_entity_id`, `to_level_id` | idem | index `(to_entity_id)` |
| `territory` | enum (`whole`, `partial`) | `sub_entities` et `geometry` viendront avec leurs tables |
| `share` | `numeric` | `NULL` ; `CHECK (share > 0 AND share <= 1)` |
| `share_basis` | enum (`area`, `population`) | `NULL` ; `CHECK ((share IS NULL) = (share_basis IS NULL))` |

- `CHECK (territory = 'partial' OR share IS NULL)` : la totalité vaut 1, on ne la stocke pas.
- Un transfert `partial` sans description du territoire ni part est admis (réponse A14) : la part reste inconnue, et l'écart du recalcul est documenté (Q13).
- Une part renseignée exige une citation de rôle `share` (trigger de validation différé).
- « Somme des parts d'une source ≤ 1 dans un événement » : contrôle d'anomalie, consigné dans le rapport du lot (A19).

### 5.6 Validité des systèmes de découpage

**`system_validity_assertion`** (réponse A16) : sans colonne de contenu ; le sujet est le système, et seule la période de l'assertion compte.

### 5.7 Variables

**`variable`** (modèle §8.1)

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire ; clé de partition des observations |
| `label`, `definition`, `unit` | `text` | |
| `method` | `text` | `NULL` |
| `value_type` | enum (`quantity`, `rate`, `category`, `text`) | |
| `aggregation_rule` | enum (`additive`, `non_additive`) | |
| `class_breaks` | `numeric[]` | `NULL` ; seuils de discrétisation (politique §5.4) |
| `class_breaks_rationale` | `text` | `NULL` ; `CHECK ((class_breaks IS NULL) = (class_breaks_rationale IS NULL))` |

Les seuils et leur justification viennent d'un **fichier déclaratif versionné** dans le dépôt, chargé en base (réponse A20) : toute modification passe par une PR, et l'historique est celui de git. Emplacement proposé : `db/reference/variables.toml` (§9, N8).

### 5.8 Observations

**`observation`** : `PARTITION BY LIST (variable_id)`, une seule partition `observation_default` (`DEFAULT`) en tranche 1.

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `bigint` identité | propagée aux partitions |
| `variable_id` | `integer` → `variable` | clé de partition |
| `entity_id` | `integer` → `entity` | |
| `entity_role` | enum (`subject`, `origin`, `destination`, `reference_area`) | `CHECK (entity_role = 'subject')` en tranche 1 (réponse A7) |
| motif de période, préfixé `reference_` | | **période de référence** (A5) ; pas de période de validité |
| `value` | `numeric` | valeur exacte telle que publiée |
| `margin` | `numeric` | `NULL` |
| `nature` | enum (`original`, `derived`) | |
| `geography_date` | `int4` | `NULL` ; `CHECK ((nature = 'derived') = (geography_date IS NOT NULL))` |
| `derivation_id` | `integer` → `derivation` | `NULL` ; `CHECK ((nature = 'derived') = (derivation_id IS NOT NULL))` |
| `certainty` | enum | sans valeur par défaut |
| `authority_entity_id` | `integer` → `entity` | `NULL` |
| `import_batch_id` | `integer` → `import_batch` | `NULL` |
| `locator` | `text` | `NULL` ; `CHECK ((import_batch_id IS NULL) = (locator IS NULL))` ; désigne la **cellule** (voir ci-dessous) |

- Clé primaire `(variable_id, id)` ; toute contrainte d'unicité inclut `variable_id`.
- **Import rejouable** (correction du 2026-10-17) : `UNIQUE (variable_id, import_batch_id, locator)`. Rejouer tout ou partie d'un lot ne crée aucun doublon : une cellule de la source ne produit qu'une observation par lot. Les observations hors lot (`import_batch_id` et `locator` `NULL`) ne sont pas concernées, les `NULL` étant distincts.
- **Localisateur d'une observation importée** : il désigne la cellule, ligne **et** colonne, pas seulement la ligne, puisqu'une ligne de la source porte souvent plusieurs valeurs (populations de plusieurs recensements). Forme : `row=<n>;column=<nom>`, où `n` est le numéro de ligne dans le fichier publié (ligne d'en-tête = 1) et `nom` l'en-tête de colonne tel que publié ; pour un classeur, `sheet=<nom>;row=<n>;column=<nom>`. La base vérifie seulement que le localisateur n'est pas vide ; la forme est un contrôle automatique du lot.
- Index : `(variable_id, entity_id, reference_start_latest)`, `(derivation_id) WHERE derivation_id IS NOT NULL`. L'index d'unicité ci-dessus sert aussi aux lectures par lot.
- **Pas de colonne de statut** : le statut effectif se lit sur les révisions (§5.12). Valider un lot ne réécrit aucune observation.
- **P3** (D3) : le `CHECK` couvre le cas « lot et localisateur ». Sinon, le trigger de contrainte différé, `WHEN (NEW.import_batch_id IS NULL)`, exige au moins une ligne dans `observation_citation`, **ou** une dérivation interne avec au moins une ligne dans `derivation_input`.
- Les rôles d'entité multiples (flux) passeront par une table `observation_entity (variable_id, observation_id, entity_id, entity_role)`, décrite ici et reportée.

**`observation_citation`** : `(variable_id, observation_id) → observation`, `citation_id → citation`, `citation_role` ; clé primaire sur les quatre colonnes.

### 5.9 Dérivations

**`derivation`** : **partagée** par les observations d'une même exécution et d'une même méthode (réponse A8).

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire |
| `derivation_kind` | enum (`internal`, `external`) | |
| `author_entity_id` | `integer` → `entity` | `NULL` pour l'atlas ; `CHECK ((derivation_kind = 'internal') = (author_entity_id IS NULL))` |
| `method` | enum (`simple_sum`, `area_weighting`, `population_weighting`, `interpolation`, `mean_annual_growth_rate`) | `NULL` ; obligatoire si interne |
| `method_citation_id` | `bigint` → `citation` | `NULL` ; obligatoire si externe (méthode **citée**, modèle §8.4) |
| `method_summary` | `text` | `NULL` |
| `inputs_description` | `text` | `NULL` ; entrées d'une dérivation externe, décrites en texte |
| `caveat` | `text` | `NULL` |
| `contributor_id` | `integer` → `contributor` | |
| `recorded_at` | `timestamptz` | fixé par trigger à `now()` |

Une exécution de recalcul vaut pour une date source et une date de géographie : sa table de passage est unique (§9, N5). `derivation`, `derivation_input`, `crosswalk` et `crosswalk_transfer` sont **immuables** (trigger `BEFORE UPDATE`) : une dérivation à refaire est une nouvelle exécution.

**`derivation_input`** : les entrées restent liées **par observation** (A8).

| Colonne | Type | Contraintes |
|---|---|---|
| `variable_id`, `observation_id` | → `observation` | l'observation dérivée |
| `input_variable_id`, `input_observation_id` | → `observation` | l'entrée ; index, pour signaler les dérivées à recalculer |
| | | clé primaire sur les quatre colonnes |

**`crosswalk`** (table de passage, modèle §8.4)

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `bigint` identité | clé primaire |
| `derivation_id` | `integer` → `derivation` | |
| `from_entity_id`, `to_entity_id` | `integer` → `entity` | `UNIQUE (derivation_id, from_entity_id, to_entity_id)` |
| `share` | `numeric` | `NULL` si une part composée est inconnue (A14) ; `CHECK (share > 0 AND share <= 1)` |

**`crosswalk_transfer`** : `(crosswalk_id → crosswalk, transfer_assertion_id → transfer_assertion)`, clé primaire sur les deux. Ce sont les transferts composés, donc la source des parts (citation par transitivité).

### 5.10 Lots d'import

**`import_batch`** (modèle §10.5)

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `integer` identité | clé primaire |
| `citation_id` | `bigint` → `citation` | la citation du jeu de données, avec son millésime |
| `owner_id` | `integer` → `contributor` | fixé par trigger au contributeur de `current_user`, jamais déclaré |
| `reviewer_id` | `integer` | `NULL` |
| `reviewer_kind` | enum `contributor_kind` | `NULL` |
| `recorded_at` | `timestamptz` | fixé par trigger à `now()` |
| `procedure` | `text` | |
| `scope` | `jsonb` | territoire, période, variables |
| `validation_report` | `jsonb` | `NULL` ; contrôles, comptes, anomalies (A19), échantillon tiré |
| `batch_status` | enum (`proposed`, `validated`, `partially_validated`, `rejected`) | état courant, recopié de la dernière révision du lot |

`procedure` et `scope` sont figés à la création ; `validation_report` ne s'écrit que tant que le lot est `proposed`, et se fige à la décision. La révision d'un lot n'a pas d'instantané : ce gel garantit que le rapport sur lequel le vérificateur a décidé ne change plus.

Vérificateur (réponse A13), entièrement déclaratif :
- clé étrangère `(reviewer_id, reviewer_kind) → contributor (id, contributor_kind)` ;
- `CHECK (reviewer_kind = 'human')` ;
- `CHECK (reviewer_id <> owner_id)` ;
- `CHECK ((reviewer_id IS NULL) = (reviewer_kind IS NULL))` ;
- `CHECK (batch_status = 'proposed' OR (reviewer_id IS NOT NULL AND validation_report IS NOT NULL))`.

`reviewer_id` n'est pas déclaré : à la décision, le trigger le fixe au contributeur de `current_user`, qui doit être membre du rôle de vérification (§5.13).

**Version de source déjà importée** (correction du 2026-10-17). Contrôle automatique obligatoire de la procédure d'import (modèle §10.5) : un nouveau lot est refusé, sans relecture, si un lot `validated` ou `partially_validated` couvre déjà la même version de la source (même `source_work`, donc même millésime) avec un périmètre qui recoupe le sien (même variable, territoires et périodes qui se chevauchent). Un lot `rejected` ne bloque pas : le lot corrigé est soumis comme un nouveau lot (§10.5, règle 5). Un erratum, publié comme une nouvelle version, est une autre œuvre et n'est pas bloqué. Le périmètre étant en `jsonb`, ce contrôle est fait par le pipeline d'import ; la base ne garantit que l'absence de doublon à l'intérieur d'un lot (§5.8). Révision proposée du modèle : §8.4.

Le statut est historisé par les **révisions du lot** (réponse A12). Valider le lot passe au statut `validated` les assertions du lot encore au statut `proposed` (modèle §10.5), ce qui crée leurs révisions ; les observations du lot, elles, ne sont pas réécrites.

**Assertions d'un lot.** `assertion` n'a pas de colonne de lot : les assertions d'un lot sont celles dont la révision `create` porte son `import_batch_id`, renseigné par `SET LOCAL atlas.import_batch_id` dans la transaction d'import. Le passage du lot à `validated` est propagé par le trigger `AFTER UPDATE OF batch_status` d'`import_batch`, sous le rôle du vérificateur, donc sous la même garde des statuts.

**Appartenance à un lot** (E13). Un lot n'accueille de nouvelles données que tant qu'il est `proposed`, et seulement de son responsable : une observation n'est insérée que dans un tel lot (trigger par instruction sur `observation`, sans appel ligne par ligne), et une révision `create` d'assertion ne porte que l'identifiant d'un tel lot. Le lot d'une observation est ensuite figé. Sans cette garde, une observation versée dans un lot déjà validé prendrait son statut sans relecture.

**Lot partiellement validé** (N4). Les observations écartées sont retirées (révision individuelle `withdrawn`) **avant** la décision `partially_validated`, tant que leur statut est `proposed` : après la décision elles valent `validated`, et `validated` → `withdrawn` n'est pas une transition admise (§5.13). Il en va de même des assertions écartées d'un lot.

### 5.11 Révisions

**`revision`** : strictement en ajout seul (D4). Triggers `BEFORE UPDATE` et `BEFORE DELETE` qui refusent ; droits `UPDATE`, `DELETE`, `TRUNCATE` non accordés.

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `bigint` identité | clé primaire ; départage des révisions de même `recorded_at` |
| `recorded_at` | `timestamptz` | fixé par trigger à `now()` (début de la transaction) ; aucune borne supérieure |
| `contributor_id` | `integer` → `contributor` | |
| `operation` | enum (`create`, `correct`, `review_status_change`) | |
| `review_status` | enum `review_status` | `NULL` pour une révision de lot |
| `batch_status` | enum `batch_status` | `NULL` sauf pour une révision de lot |
| `reason` | `text` | `NULL` ; obligatoire pour une correction, un retrait ou un rejet |
| `import_batch_id` | `integer` → `import_batch` | `NULL` ; lot dont la révision fait partie, ou lot visé |
| `assertion_id` | `bigint` → `assertion` | `NULL` |
| `observation_variable_id`, `observation_id` | → `observation` | `NULL` |
| `snapshot` | `jsonb` | `NULL` ; état **résultant** : tronc, contenu du type, liens de citation ; les contenus immuables sont **référencés**, pas recopiés |

Cibles, par `CHECK` :
- révision d'**assertion** : `assertion_id` seul, avec `review_status` et `snapshot` ;
- révision d'**observation** : la paire d'observation seule, avec `review_status` et `snapshot` ;
- révision de **lot** : ni assertion ni observation, `import_batch_id` et `batch_status` renseignés, `snapshot` `NULL`.

Index : `(assertion_id, recorded_at, id)`, `(observation_variable_id, observation_id, recorded_at, id)`, `(import_batch_id, recorded_at, id)`, chacun partiel (`WHERE … IS NOT NULL`).

`previous_content` (modèle §10.1) n'est pas stocké : c'est l'instantané de la révision précédente.

**Contenus référencés, non recopiés** (correction du 2026-10-17). L'instantané d'une `geometry_assertion` ne contient pas `shape` : la géométrie étant immuable (§5.4), la ligne de `geometry_assertion` est la même à toute date R, et l'identifiant de l'assertion suffit. Revue des autres contenus volumineux :

| Contenu | Traitement |
|---|---|
| Géométrie (`shape`) | Immuable, référencée par l'identifiant de l'assertion |
| Citations (extrait, localisateur) | Déjà immuables ; l'instantané ne garde que les identifiants des liens |
| Dérivation, entrées, table de passage | Immuables (§5.9), hors instantané |
| `validation_report`, `procedure`, `scope` du lot | Figés (§5.10) ; la révision du lot n'a pas d'instantané |
| `historical_date` | Immuable ; l'instantané garde `start_date_id` et `end_date_id` |
| Nom, statut, identifiant, appartenance, relation, transfert, participation, dates d'événement | Petits contenus, recopiés dans l'instantané |
| Observation | Petit contenu, recopié dans l'instantané de sa révision individuelle |
| À venir : zones floues (`core`, `max_extent`), récits | Même règle que les géométries, à leur arrivée |

**Mécanique des triggers**
- Le **contributeur** n'est jamais déclaré : les triggers le retrouvent par `contributor.db_role = current_user` (§5.13). Toutes les fonctions de trigger sont `SECURITY INVOKER`, pour que `current_user` reste le rôle de connexion.
- Le reste du contexte est déclaratif, dans des variables `SET LOCAL` : `atlas.reason`, `atlas.import_batch_id`. Ces valeurs ne confèrent aucun droit.
- `revision` ne reçoit que des lignes écrites par les triggers : un trigger `BEFORE INSERT` refuse l'insertion si `pg_trigger_depth() < 2` (insertion directe), et fixe lui-même `contributor_id` et `recorded_at`.
- **Assertions** : un trigger de contrainte différé, sur `assertion`, les tables de type et `assertion_citation`, écrit au commit **au plus une révision par assertion et par transaction** : il ne fait rien si une révision de cette assertion a déjà ce `recorded_at`. Comme il s'exécute au commit, l'instantané reflète l'état final. L'opération se **déduit** : `create` si l'assertion est née dans la transaction, `review_status_change` si seul le statut a changé, `correct` sinon.
- **Observations** : trigger `AFTER INSERT … WHEN (NEW.import_batch_id IS NULL)` et `AFTER UPDATE`. Une insertion par lot n'appelle **aucune** fonction ligne par ligne : la clause `WHEN` s'évalue sans appel, et la révision du lot vaut pour toutes ses observations (ADR 0003). Une correction ultérieure crée une révision individuelle ; comme pour une assertion (§5.13), elle ramène une observation `validated` à `proposed` et laisse tout autre statut inchangé.
- **Statut d'une observation** : une observation n'ayant pas de colonne de statut, son changement de statut sans changement de contenu (contestation, retrait, validation) passe par la fonction `set_observation_review_status(variable_id, observation_id, review_status, reason)`, `SECURITY INVOKER`. Elle écrit la révision individuelle de l'observation, avec le statut demandé et le motif ; la garde des statuts s'applique à cette révision. Les appelants n'écrivent jamais de mise à jour sans effet.
- **Lots** : trigger `AFTER INSERT OR UPDATE OF batch_status` sur `import_batch`, qui écrit la révision du lot.

### 5.12 Vues

- **`revision_period`** : pour chaque révision, `superseded_at = lead(recorded_at) OVER (PARTITION BY cible ORDER BY recorded_at, id)`, appuyée sur les index de 5.11. La période de transaction est `[recorded_at, superseded_at[`.
- **`observation_review_status`** (fonction paramétrée par R) : dernière révision individuelle de l'observation à R ; à défaut, dernière révision du lot à R, avec la correspondance `proposed` → `proposed`, `validated` et `partially_validated` → `validated`, `rejected` → `withdrawn` (§9, N4).
- **`entity_existence`** (réponse A1), déduite, jamais saisie :
  - **début** : date `effective` de l'événement d'une participation `created` ; à défaut, nature `unknown`, avec pour date au plus tard la première attestation (le plus petit `start_latest` de ses assertions non retirées). Pour une commune présente en 1968, c'est sa première attestation dans le COG ;
  - **fin** : date `effective` de l'événement d'une participation `dissolved` ; à défaut, `ongoing` si l'une de ses assertions non retirées est `ongoing` (affirmation citée) ; sinon `unknown`, avec pour date au plus tôt la dernière attestation ;
  - plusieurs participations concurrentes donnent plusieurs lignes ; le choix relèvera des préférences (tranche 2).
  - Vue simple en tranche 1 ; un cache maintenu par trigger ne viendra que si le banc d'essai l'exige.
- **Transaction et temps R** : `recorded_at` est l'heure de début de la transaction. Un état au temps R n'est reproductible que pour un R antérieur à la plus ancienne transaction en cours ; une publication fixe donc un R passé.

### 5.13 Rôles et séparation des droits

Correction du 2026-10-17. Une variable de session peut être renseignée par toute connexion : si le contributeur était déclaré, un agent pourrait valider son propre lot. L'identité d'un contributeur est donc celle de son **rôle de connexion**, et le droit de valider est attaché à un **rôle PostgreSQL**.

**Rôles de groupe** (`NOLOGIN`), créés par la première migration du schéma. Les rôles étant communs à toutes les bases d'un même serveur (`db-dev` porte la base de développement et la base jetable de `check.sh`), leur création est gardée : un rôle déjà présent n'est pas recréé. Les migrations sont lancées par dbmate avec le superutilisateur, qui crée les extensions (PostGIS l'exige) puis prend le rôle `atlas_owner` (`SET ROLE`) pour créer les objets, et le quitte en fin de migration (`RESET ROLE`). Le schéma `public` accorde `CREATE` à `atlas_owner`. Les droits des rôles de groupe sont accordés par la dernière migration du schéma.

| Rôle | Droits |
|---|---|
| `atlas_owner` | Propriétaire du schéma ; seul rôle des migrations. Jamais utilisé pour écrire des données |
| `atlas_import` | Lecture de tout ; insertion des entités, événements, assertions et tables de type, citations, dates historiques, œuvres, observations, dérivations, lots ; correction et contestation. **Jamais** de validation |
| `atlas_review` | Les droits d'`atlas_import`, plus les décisions : passage à `validated` ou `withdrawn` d'une assertion ou d'une observation, et à `validated`, `partially_validated` ou `rejected` d'un lot |

Aucun des deux n'a de droit `DELETE` ni `TRUNCATE`, ni de droit de créer des objets (donc pas de trigger qui leur appartienne).

**Rôles de connexion** (`LOGIN`) : un par contributeur, membre d'un seul rôle de groupe, enregistré dans `contributor.db_role`. Un rôle de connexion membre d'`atlas_review` correspond à un contributeur `human`. Les rôles de connexion portent des mots de passe : ils ne sont **jamais créés par une migration** (rien de secret dans git), mais par un script qui demande le mot de passe de façon interactive.

**Garde des statuts** : un trigger `BEFORE INSERT OR UPDATE` sur `assertion`, `observation` (via ses révisions) et `import_batch` vérifie chaque transition avec `pg_has_role(current_user, 'atlas_review', 'MEMBER')` :

| Transition | `atlas_import` | `atlas_review` |
|---|---|---|
| création en `proposed` | oui | oui |
| création dans un autre statut | non | non |
| `validated` → `contested` (contestation sourcée) | oui | oui |
| `validated` → `proposed` (correction de contenu) | oui | oui |
| `withdrawn` → `proposed` (réouverture) | oui | oui |
| `proposed` → `validated` ; `contested` → `validated` | non | oui |
| `proposed` → `withdrawn` ; `contested` → `withdrawn` | non | oui |
| lot `proposed` → `validated`, `partially_validated`, `rejected` | non | oui |

Toute autre transition est refusée, notamment `proposed` → `contested` (une proposition se rejette) et `contested` → `proposed` (une contestation se règle par `validated` ou `withdrawn`) : modèle §10.1, version 3.2. La validation est toujours une décision distincte de la création. Une correction de contenu sur une assertion `validated` la ramène à `proposed` : elle repasse en relecture ; sur une assertion dans un autre statut, elle laisse le statut inchangé.

**Identifiants** :
- le `.env` lu par les pipelines et par Claude Code ne contient que les identifiants d'un rôle de connexion membre d'`atlas_import` ;
- les identifiants d'un rôle de vérification ne figurent **jamais** dans le `.env` ni dans aucun fichier lisible par les pipelines ou par Claude Code : le vérificateur humain les saisit lui-même à la connexion ;
- la séparation ne tient que si le **superutilisateur** et `atlas_owner` sont eux aussi hors de portée : un superutilisateur peut prendre n'importe quel rôle (§12, essai 4), et le propriétaire peut désactiver les triggers. Aujourd'hui, `ATLAS_REF_USER` dans `.env` est le superutilisateur créé par l'image PostGIS, et `scripts/db-ref-migrate.sh` s'en sert. Ses identifiants doivent sortir du `.env` avant le premier import (`docs/backlog.md`).

**Base de développement** : jetable, elle reçoit les mêmes rôles, avec des rôles de connexion d'essai dont les mots de passe, connus, figurent dans `.env.example` (accepté par le mainteneur le 2026-10-17). Ils n'existent pas sur la base de référence, et ses rôles n'ont rien en commun avec ceux-ci. Ils sont créés par `scripts/db-dev-roles.sh`, qui ne vise que le service `db-dev` : `atlas_dev_agent`, membre d'`atlas_import`, contributeur `agent` ; `atlas_dev_reviewer`, membre d'`atlas_review`, contributeur `human`. Le script enregistre leurs contributeurs dans la base visée ; `scripts/db-dev-reset.sh` et `check.sh` l'appellent.

**Connexions dans le conteneur de référence.** Le `pg_hba.conf` de l'image PostGIS accepte sans mot de passe (`trust`) les connexions locales et en boucle locale (constaté sur `db-dev`, même image : §12, essai 5) : `docker exec … psql` contournerait les rôles. Pour `db-ref`, un fichier versionné, `db/pg_hba-ref.conf`, exige `scram-sha-256` pour toute connexion, locale comprise. Il est monté en lecture seule et désigné par `-c hba_file` (`compose.yaml`), ce qui vaut aussi pour un volume déjà initialisé, contrairement à `POSTGRES_INITDB_ARGS`. Le contrôle de santé (`pg_isready`) ne s'authentifie pas et fonctionne toujours. `db-dev` garde la configuration de l'image.

**Règles de refus de Claude Code** (`.claude/settings.json`, `permissions.deny`) : toute commande `docker` ou `docker-compose`, en Bash comme en PowerShell, qui mentionne `db-ref`, `dbmate-ref` ou `atlas-ref` (service, conteneur `atlas-db-ref-1`, volume `atlas_atlas-ref`), et le lancement de `scripts/db-ref-migrate.sh`, qui ne se fait que depuis `main` et par un humain.

**Limite assumée.** La séparation des rôles protège contre une **erreur de l'agent** (un pipeline ou Claude Code qui validerait son propre lot), **pas contre un acteur qui contrôle la machine**. Qui dispose de Docker sur l'hôte peut lire les fichiers du volume, remplacer `compose.yaml` ou `pg_hba-ref.conf`, ou démarrer un autre conteneur sur le volume ; les règles de refus portent sur le texte des commandes et se contournent par une indirection (variable, script). Ces mesures rendent l'erreur impossible par inadvertance et visible dans l'historique ; elles ne remplacent ni le contrôle d'accès à la machine, ni la sauvegarde hors de la machine (§4), ni la vérification humaine des lots.

---

## 6. Activation du partitionnement des observations

PostgreSQL refuse de créer ou d'attacher une partition tant que la partition par défaut contient des lignes qui lui reviendraient. L'activation pour une variable X se fait donc dans **une seule migration**, exécutée dans une seule transaction (comportement par défaut de dbmate) :

1. **Relever** les comptes de lignes de `observation`, par variable.
2. **Retirer** les clés étrangères qui visent `observation` (`observation_citation`, `derivation_input` ×2, `revision`). PostgreSQL refuse de détacher une partition dont des lignes sont référencées (vérifié, §12, essai 1).
3. `ALTER TABLE observation DETACH PARTITION observation_default`. Les triggers clonés (y compris le refus de suppression) sont retirés de la table détachée. `DETACH … CONCURRENTLY` est interdit en présence d'une partition par défaut, et ne s'exécute pas dans une transaction.
4. **Créer** `observation_v<X>` comme table ordinaire, avec les mêmes colonnes **sans identité** (une partition hérite de l'identité de la table partitionnée et ne peut avoir la sienne), et `CHECK (variable_id = X)`.
5. **Déplacer** : `INSERT INTO observation_v<X> SELECT * FROM observation_default WHERE variable_id = X`, puis `DELETE FROM observation_default WHERE variable_id = X`. Les identifiants sont conservés. Ce déplacement n'est pas une suppression au sens de P7 : les lignes changent de partition, pas de contenu.
6. `ALTER TABLE observation ATTACH PARTITION observation_v<X> FOR VALUES IN (X)` : le `CHECK` de l'étape 4 dispense du parcours de vérification. Index et triggers de ligne sont recréés sur la partition.
7. Ajouter à `observation_default` un `CHECK (variable_id <> ALL (ARRAY[…]))` listant toutes les variables qui ont leur partition, puis la rattacher : `ATTACH PARTITION observation_default DEFAULT`. Le `CHECK` dispense du parcours, mais son ajout parcourt la table une fois.
8. **Rétablir** les clés étrangères de l'étape 2 et les valider.
9. **Vérifier** que les comptes par variable sont égaux à ceux de l'étape 1 ; sinon, la migration échoue et la transaction est annulée.

L'attachement prend un verrou `ACCESS EXCLUSIVE` sur la partition par défaut. La base est donc indisponible en écriture pendant la migration, qui se lance hors des imports.

Le sous-partitionnement (hachage de l'entité, ou zone géographique), nécessaire quand une seule variable dépasse le milliard de lignes, sera tranché par le banc d'essai de l'ADR 0006. Les triggers de contrainte différés, avec clause `WHEN`, fonctionnent sur une table partitionnée et sont clonés sur les partitions créées ensuite (§12, essai 2).

---

## 7. Décisions sur les ambiguïtés du modèle

Réponses du mainteneur (2026-10-17), intégrées aux tables ci-dessus.

| # | Question | Décision |
|---|---|---|
| A1 | Existence d'une entité face à P2 | Déduite des participations `created`/`dissolved` (vue, ou cache maintenu par trigger, jamais saisie). Commune déjà présente en 1968 : début `unknown`, date au plus tard = première attestation dans le COG |
| A2 | Participation | Assertion citée |
| A3 | Type et dates d'un événement | Assertions : dates typées (`effective`, `act`, `signature`, `entry_into_force`) ; type d'événement assertion, pour des types concurrents plus tard (Q8) |
| A4 | Citation d'un événement | Pas de citation propre ; au moins une assertion de date citée |
| A5 | Période d'une observation | Période de référence, pas de période de validité |
| A6 | `lot_id NOT NULL` de l'ADR 0003 | Révision proposée (§8.1) |
| A7 | Rôles d'entité d'une observation | `subject` seulement en tranche 1, structure à rôles multiples conservée |
| A8 | Cardinalité d'une dérivation | Partagée (une exécution, une méthode) ; entrées liées par observation |
| A9 | Partage des citations | Partageables ; `citation_role` porté par le lien |
| A10 | INSEE comme entité | Catégorie `organization` ajoutée à la taxonomie |
| A11 | Unicité du triplet d'identifiant | Refus |
| A12 | Statut d'un lot | Historisé par les révisions du lot |
| A13 | Vérificateur | Consigné dans `import_batch`, contributeur humain, différent du responsable, contrôlé par la base |
| A14 | Transfert partiel sans part | Admis ; part inconnue, écart de recalcul documenté (Q13) |
| A15 | Autorité d'une appartenance | Déduite du système, non recopiée |
| A16 | Validité d'un système de découpage | Assertion |
| A17 | Point des cercles proportionnels | Calculé à l'export, de façon déterministe, méthode consignée dans le manifeste : procédé de représentation, pas affirmation géographique |
| A18 | Préférence de Q13 | Pas de table de préférences en tranche 1 : règle appliquée à l'export et consignée dans le manifeste ; préférences et points de vue en tranche 2 |
| A19 | Anomalies | Consignées dans le rapport de validation du lot |
| A20 | Seuils de discrétisation | Fichier déclaratif versionné dans le dépôt, chargé en base ; modification par PR |
| A21 | Système de coordonnées | WGS 84 (SRID 4326) ; système d'origine consigné avec la méthode ; surfaces en `geography` ou projection adaptée |

---

## 8. Révisions proposées des documents de référence

Révisions 8.1 et 8.2 validées le 2026-10-17 et appliquées aux ADR 0003, 0004 et 0009. Révision 8.4 validée le 2026-10-17 et appliquée au modèle (version 3.1) ; l'ADR 0003 est aligné sur le localisateur au niveau de la cellule. Le texte ci-dessous garde la trace des propositions.

### 8.1 ADR 0003, section « Citations des imports en masse »

Remplacer :

> chaque observation porte `lot_id NOT NULL` et `localisateur NOT NULL` (ligne ou enregistrement dans le jeu de données) ;

par :

> une observation importée par lot porte `import_batch_id` et `locator` (ligne ou enregistrement dans le jeu de données), tous deux renseignés ; un `CHECK` impose qu'ils soient renseignés ensemble ou absents ensemble. Une observation hors lot (saisie individuelle ou dérivée interne) n'en porte aucun : un trigger de contrainte différé, déclenché seulement quand `import_batch_id` est `NULL`, exige au moins une citation liée ou, pour une dérivée interne, au moins une entrée. Les imports en masse ne paient pas ce contrôle.

Motif : une dérivée interne (le taux d'évolution de la tranche 1, le recalcul par la filiation) n'a pas de lot citable, puisque l'atlas n'est jamais une source (modèle §9.3) ; elle est citée par transitivité (§8.4).

### 8.2 ADR 0004, décision 6

Remplacer le paragraphe qui fait du point une géométrie dérivée (« Ce point est une géométrie dérivée… citation : la source du polygone ») par :

> Ce point n'est pas une assertion : c'est un **procédé de représentation**, calculé à l'export de façon déterministe (centre du plus grand cercle inscrit, `ST_MaximumInscribedCircle`, avec une tolérance fixée), à partir du polygone de la même version. Il n'est pas stocké en base. Sa méthode et ses paramètres sont consignés dans le manifeste de la publication (ADR 0009). Le contrôle d'export « chaque point est à l'intérieur de son polygone » est maintenu.

Ajouter au manifeste (ADR 0009, `publication.json`) les **procédés de représentation** appliqués à l'export : méthode du point, et règle de choix de la valeur affichée (réponse A18).

### 8.3 Écart provisoire au modèle (§10.2)

En tranche 1, la valeur INSEE affichée par défaut (Q13) n'est pas une préférence stockée : la règle est appliquée à l'export et consignée dans le manifeste (A18). L'écart prend fin avec les tables de préférences (tranche 2). Il peut être signalé dans le §14 du modèle.

### 8.4 Modèle, §10.5 : contrôles de la tranche 1

Ajouter au tableau des paramètres de la tranche 1 la ligne :

> | Version déjà importée | Le lot est refusé si un lot validé ou partiellement validé couvre déjà la même version de la source (même œuvre, même millésime) sur un périmètre qui recoupe le sien. Un lot rejeté ne bloque pas ; un erratum est une autre version |

Et préciser, dans les règles du lot, que le localisateur d'une valeur importée désigne la **cellule** (ligne et colonne), pas seulement la ligne.

Le modèle est figé pour la tranche 1 : cette révision passe par une nouvelle version du document, après validation.

### 8.5 Révisions issues des migrations

Écarts relevés en traduisant ce document en migrations, validés par le mainteneur le 2026-10-17 et reportés dans les sections concernées. La révision E6 est aussi une révision du modèle (§10.1, version 3.2).

| # | Point | Décision | Section |
|---|---|---|---|
| E1 | Ordre des migrations et dépendances | Table nue `event` créée avec les référentiels ; clé `observation.import_batch_id` ajoutée avec les lots ; rôles de groupe créés en premier, droits accordés en dernier | §5.13 |
| E2 | Propriétaire des objets | Extensions créées par le superutilisateur, objets créés sous `SET ROLE atlas_owner` | §5.13 |
| E3 | Rôles communs au serveur | Création gardée | §5.13 |
| E4 | Responsable d'un lot | `owner_id` fixé par trigger au contributeur de `current_user` | §5.10 |
| E5 | Statut d'une observation | Fonction `set_observation_review_status` ; une correction ramène à `proposed` | §5.11 |
| E6 | Transitions de statut | Ajout de `validated` → `proposed` par une correction ; `proposed` → `contested` et `contested` → `proposed` refusés ; création dans un autre statut que `proposed` refusée | §5.13 ; modèle §10.1 |
| E7 | Transaction révisée | Transaction qui renseigne `atlas.reason` | §5.3 |
| E8 | Troncature | Trigger `BEFORE TRUNCATE` qui refuse, sur toutes les tables | §1 |
| E9 | Rôles de connexion d'essai | `scripts/db-dev-roles.sh`, sur `db-dev` seulement | §5.13 |
| E10 | Assertions d'un lot | Retrouvées par leur révision `create` ; propagation de la validation par trigger | §5.10 |
| E11 | Codes des référentiels | Chargés par migration, avec les libellés des catégories | §5.1 |
| E12 | N3 (copie archivée exigée à la validation), chargement de `db/reference/variables.toml` (N8) | Hors des migrations initiales, restent ouverts | `docs/backlog.md` |
| E13 | Appartenance à un lot | Ajout seulement à son propre lot `proposed` (observations et révisions `create` d'assertions) ; lot d'une observation figé | §5.10 |

---

## 9. Points nouveaux issus de la conception

Points qui découlent de la conception et que le modèle ne tranche pas. **Validés par le mainteneur le 2026-10-17.**

| # | Point | Proposition |
|---|---|---|
| N1 | Période des assertions dont le sujet est un événement (participation, transfert, type, date) | Pas de période de validité : elle se déduit de la date de l'événement (principe de stockage). La date d'un événement est le contenu de `event_date_assertion` |
| N2 | Bornes inconnues | Début inconnu : `start_earliest` `NULL`. Fin inconnue : la date qui atteste la disparition n'a pas de lien vers `historical_date`, elle est appuyée par une citation de rôle `date`. Aucune fin inconnue en tranche 1 ; à revoir à la première qui en a |
| N3 | Copie archivée exigée à la validation (politique §3.5) | Contrôle par le trigger de validation lors du passage à `validated`, avec une colonne d'exception justifiée sur `citation` ; à préciser avec la procédure d'import |
| N4 | Statut d'une observation d'un lot partiellement validé | `partially_validated` vaut `validated` pour les observations sans révision propre ; les observations écartées reçoivent une révision individuelle `withdrawn` |
| N5 | Portée d'une exécution de dérivation | Une exécution par couple (date source, date de géographie), donc une table de passage par exécution |
| N6 | Géométries | Validité OGC contrôlée dans le lot, pas par `CHECK` ; plusieurs géométries parentes (union) reportées |
| N7 | Mise à jour des identités | `entity` et `event` n'acceptent aucune mise à jour |
| N8 | Fichier des seuils | `db/reference/variables.toml` |
| N9 | Opération d'une révision | Déduite de la transaction (`create`, `review_status_change`, `correct`), pas saisie |
| N10 | Assertion de date exigée pour un événement | Quel que soit son statut de révision |
| N11 | Portée du refus des codes en double | Statuts `proposed`, `validated` et `contested` : seul un code retiré libère le triplet |

---

## 10. Termes proposés pour le glossaire

Validés le 2026-10-17 et ajoutés à `docs/glossaire.md` (version 2) (CLAUDE.md, règle 5).

| Français | Anglais | Justification |
|---|---|---|
| type d'assertion | `assertion_type` | Colonne discriminante du tronc commun |
| suffixe des tables de type | `_assertion` | Évite `name` et `geometry` comme noms de table |
| type d'événement | `event_type` | Réponse A3 |
| date d'un événement ; type de date : d'effet, de l'acte, de signature, d'entrée en vigueur | `event_date` ; `event_date_kind` : `effective`, `act`, `signature`, `entry_into_force` | Réponse A3, Q12 |
| validité d'un système de découpage | `system_validity` | Réponse A16 |
| existence (d'une entité) | `existence` | Vue `entity_existence`, réponse A1 |
| nature du contributeur : humain, agent | `contributor_kind` : `human`, `agent` | Modèle §10.5 (« un agent importe et un humain vérifie ») |
| vérificateur (d'un lot) | `reviewer` | Modèle §10.5 ; distinct de `owner` |
| œuvre parente | `parent_work` | Modèle §9.1 (une œuvre peut en contenir d'autres) |
| territoire transféré : totalité, partiel | `territory` : `whole`, `partial` | Modèle §7.2 ; `sub_entities` et `geometry` plus tard |
| base de la part : surface, population | `share_basis` : `area`, `population` | Modèle §7.2 |
| catégories de premier niveau : politique, administrative, statistique, culturelle, naturelle, lieu, organisation | `political`, `administrative`, `statistical`, `cultural`, `natural`, `place`, `organization` | Modèle §4.2, réponse A10 |
| sous-type de relation | `relation_subtype` | Modèle §5.5 |
| rang (d'un niveau) | `rank` | Modèle §4.3 |
| libellé, définition, unité | `label`, `definition`, `unit` | Modèle §8.1 |
| type de valeur : quantité, taux, catégorie, texte | `value_type` : `quantity`, `rate`, `category`, `text` | Modèle §8.1 |
| règle de conversion (d'une date) | `conversion_rule` | Modèle §3.1 |
| calendriers : grégorien, julien, républicain | `gregorian`, `julian`, `french_republican` | Valeurs de `source_calendar` |
| granularités : jour, mois, année, décennie, siècle, millénaire | `day`, `month`, `year`, `decade`, `century`, `millennium` | Valeurs de `granularity` |
| rôles de citation : valeur, date, géométrie, part | `value`, `date`, `geometry`, `share` | Modèle §9.2 et §7.2 |
| nature de la dérivation | `derivation_kind` | Colonne portant `internal` / `external` |
| taux d'évolution annuel moyen | `mean_annual_growth_rate` | Méthode de dérivation de la tranche 1 (modèle §14.2) |
| résumé de la méthode ; description des entrées | `method_summary` ; `inputs_description` | Modèle §8.4 (dérivation externe) |
| seuils de discrétisation | `class_breaks` | Politique §5.4, réponse A20 |
| système de coordonnées d'origine | `source_crs` | Réponse A21 |
| copie archivée de la licence | `license_archived_copy` | Politique §4.3 |
| instantané (d'une révision) | `snapshot` | D4 |
| remplacée le (fin de la période de transaction) | `superseded_at` | D4, vue `revision_period` |
| entités d'une observation | `observation_entity` | Réponse A7 |
| tables de liaison | `assertion_citation`, `observation_citation`, `derivation_input`, `crosswalk_transfer` | Composés de termes existants |
| rôle de connexion d'un contributeur | `db_role` | §5.13 |
| rôles de groupe : propriétaire, import, vérification | `atlas_owner`, `atlas_import`, `atlas_review` | §5.13 |

**Termes proposés par les migrations** (§8.5), **à valider** avant leur ajout au glossaire. Un type énuméré porte le nom de sa colonne ; quand deux colonnes de même nom ont des valeurs différentes, ou que le nom seul serait trop vague pour un objet global de la base, il est préfixé par sa table.

| Français | Anglais | Justification |
|---|---|---|
| changer le statut d'une observation | `set_observation_review_status` | Fonction de E5, composée de termes du glossaire |
| type énuméré de la méthode d'une géométrie | `geometry_method` | `method` existe aussi pour la dérivation, avec d'autres valeurs |
| type énuméré de la méthode d'une dérivation | `derivation_method` | Idem |
| type énuméré du rôle d'une participation | `participation_role` | `role` seul est trop vague comme nom de type global |

---

## 11. Hors du périmètre de la tranche 1

Reportés, avec leur déclencheur :

- **Frontières** (`boundary`) et **zones floues** (`fuzzy_zone`) : tranche 2.
- **Dimensions et membres** (`dimension`, `dimension_member`) : première tranche électorale ; leur clé devra inclure `variable_id`.
- **Points de vue, préférences, états matérialisés** (`viewpoint`, `preference`, `materialized_state`) : tranche 2 (A18).
- **Tables de publication** (`WITHOUT OVERLAPS` sur le noyau, ADR 0004) : avec la chaîne d'export.
- **Anomalies** comme table (`anomaly`) : en tranche 1, rapport de validation (A19).
- **Relation `recognizes`** et souveraineté, contrôle de fait : tranche 2.
- **Correspondance entre variables** (`variable_mapping`) et entre niveaux (Q15) : tranche 2.

---

## 12. Essais sur la base de développement

Petits essais SQL, le 2026-10-17, sur PostgreSQL 18.6 (image `postgis/postgis:18-3.6`), dans une base jetable `atlas_essai` créée puis supprimée dans `db-dev`. Ils lèvent les trois points « à vérifier » du document et éprouvent la séparation des rôles (§5.13). Les scripts ne sont pas versionnés : les migrations reprendront ces constructions, et `check.sh` les éprouvera.

| # | Essai | Résultat |
|---|---|---|
| 1a | `DETACH PARTITION` de la partition par défaut dont une ligne est référencée par une clé étrangère | **Refusé** : `removing partition "obs_default" violates foreign key constraint`. D'où l'étape 2 de la procédure (§6) |
| 1b | Créer une partition `FOR VALUES IN (2)` quand la partition par défaut contient une ligne de la variable 2 | **Refusé** : `updated partition constraint for default partition "obs_default" would be violated by some row` |
| 1c | Procédure complète du §6 en une transaction (retrait de la clé, détachement, table sans identité avec `CHECK`, déplacement, rattachement, `CHECK` sur la partition par défaut, rattachement par défaut, clé rétablie) | **Réussie** : lignes dans les bonnes partitions, identifiants conservés ; une insertion ultérieure dans la variable 1 reçoit l'identifiant suivant de la séquence de la table partitionnée et va dans la nouvelle partition |
| 2a | `CREATE CONSTRAINT TRIGGER … DEFERRABLE INITIALLY DEFERRED … FOR EACH ROW WHEN (new.batch IS NULL)` sur une table partitionnée | **Accepté** ; le trigger est cloné sur la partition par défaut |
| 2b | Insertion d'une ligne de lot (`batch` renseigné) sans citation | **Acceptée** : la clause `WHEN` écarte le contrôle |
| 2c | Insertion d'une ligne hors lot sans citation | Insertion acceptée, **commit refusé** par le trigger différé |
| 2d | Ligne hors lot et citation insérées dans la même transaction | **Acceptée** au commit |
| 2e | Partition créée **après** le trigger, puis insertion hors lot sans citation | Le trigger est **cloné** sur la nouvelle partition ; commit refusé |
| 3a | Clé étrangère composite `(end_date_id, end_latest_dated)`, où `end_latest_dated` est une colonne générée stockée | **Acceptée** à la création |
| 3b | Fin datée conforme à la date historique | Acceptée |
| 3c | Fin datée dont la borne au plus tard diffère de la date historique | **Refusée** par la clé étrangère |
| 3d | Fin inconnue, `end_latest` libre | Acceptée : la colonne générée vaut `NULL`, la clé est inactive |
| 3e | Expression `CASE` du noyau quand les bornes se croisent | Renvoie `empty`, sans erreur |
| 4a | Rôle de connexion membre du rôle d'import : passage d'une assertion à `validated` | **Refusé** par la garde des statuts (`pg_has_role`) |
| 4b | Même rôle : insertion directe dans `revision` | **Refusée** (`pg_trigger_depth() < 2`) |
| 4c | Même rôle, connecté avec ses propres identifiants : `SET ROLE` vers le rôle de vérification ou vers un vérificateur, `SET SESSION AUTHORIZATION` | **Refusés** (`permission denied`) |
| 4d | Rôle de connexion membre du rôle de vérification : validation | Acceptée ; la révision porte le contributeur retrouvé par `current_user` |
| 4e | Session ouverte avec le superutilisateur : `SET ROLE` vers n'importe quel rôle | **Accepté** : le superutilisateur contourne la séparation. D'où l'exigence que ses identifiants sortent du `.env` (§5.13) |
| 5a | Configuration de l'image PostGIS sur `db-dev` : `pg_hba.conf` | `local` et `host 127.0.0.1/32`, `::1/128` en **`trust`** : `docker exec … psql` entre sans mot de passe |
| 5b | Conteneur jetable de la même image, avec `db/pg_hba-ref.conf` monté en lecture seule et `-c hba_file` : initialisation sur volume neuf | **Réussie**, extensions PostGIS comprises (le script d'entrée fournit le mot de passe pendant l'initialisation) ; `pg_isready` répond |
| 5c | Même conteneur : `psql` local, en boucle locale, et en tant qu'utilisateur système `postgres`, sans mot de passe | **Refusés** (`fe_sendauth: no password supplied`) ; avec mot de passe : accepté, `hba_file` = `/etc/postgresql/pg_hba.conf` |
| 5d | Même conteneur : `root` modifie le fichier monté | **Refusé** (`Read-only file system`) |
| 6 | Règle de refus de `.claude/settings.json` : `docker compose … ps db-ref` lancé par Claude Code | **Refusé** par Claude Code avant exécution |
