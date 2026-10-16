# Schéma logique de la base (tranche 1)

> **Statut** : version 1 (octobre 2026), soumise à validation. Décisions D1 à D5 et réponses A1 à A21 validées par le mainteneur le 2026-10-17 ; les points de la section 9 restent à valider.
> **Portée** : conception **logique** du schéma PostgreSQL 18 + PostGIS pour le seul périmètre de la tranche 1 (`docs/modele-donnees.md`, §14.2) : population communale du Bas-Rhin, géographie communale du COG et son historique depuis 1968, géographie courante d'ADMIN EXPRESS, séries de l'INSEE en géographie courante (dérivations externes) et recalcul par le graphe de filiation. Ce document ne contient aucun SQL de migration : les migrations (ADR 0010) en découleront.
> **Références** : modèle de données (v3), ADR 0003, 0004, 0009 et 0010, glossaire (v1), politique éditoriale (v1). En cas d'écart, ces documents font foi ; les écarts proposés sont regroupés en section 8.

---

## 1. Conventions

- **Identifiants** en anglais, `snake_case`, selon `docs/glossaire.md`. Les termes absents du glossaire sont proposés en section 10 et ne valent qu'après validation.
- **Tables de type d'assertion** suffixées `_assertion` (`name_assertion`, `geometry_assertion`…), pour éviter des tables nommées comme un type PostGIS (`geometry`) ou un mot courant (`name`).
- **Vocabulaires fermés** du modèle (certitude, statut de révision, nature des bornes, nature d'une observation, rôle de participation, statut de lot, type de source…) : types `enum`. Ajouter une valeur (`ALTER TYPE … ADD VALUE`) reste compatible avec des migrations en avant uniquement ; une valeur n'est jamais retirée.
- **Vocabulaires ouverts**, que le modèle dit extensibles (catégories d'entité, types de relation, types d'événement, référentiels) : tables de référence.
- **Valeurs de données non traduites** (glossaire, §1) : statuts juridiques, noms de niveaux, types d'objet du COG (`COM`, `COMA`, `COMD`) restent des valeurs `text`.
- **Rien n'est effacé** (P7). Un trigger `BEFORE DELETE` refuse toute suppression, sur toutes les tables, et les droits `DELETE` et `TRUNCATE` ne sont pas accordés. Seules exceptions : les tables de liaison des citations, dans une transaction révisée (§5.3), et la procédure d'activation des partitions (§6).
- **Principe de stockage** (réponses du mainteneur, §7) : si le modèle prévoit qu'un fait puisse être contesté ou daté, c'est une **assertion** ; ce qui peut se **déduire** n'est pas stocké en double.

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

Pour une fin inconnue, la date qui atteste la disparition (`end_latest`) est appuyée par une citation de rôle `date` ; elle n'a pas de lien propre vers `historical_date` (§9, N2). **À vérifier** en base de développement : clé étrangère sur une colonne générée stockée (`end_latest_dated`).

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
| | | `UNIQUE (id, contributor_kind)`, cible de la clé de `import_batch` (A13) |

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

Une suppression de lien n'est admise que dans une transaction révisée (§5.11) ; le trigger différé vérifie alors qu'il reste au moins une citation.

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

Stockage en WGS 84 (A21) ; les surfaces se calculent en `geography` ou dans une projection adaptée. La validité OGC des géométries est un **contrôle automatique du lot**, pas un `CHECK` : corriger une géométrie de la source serait la modifier. Zones floues et géométries dérivées de plusieurs parents : hors tranche 1 (section 11). Le point des cercles proportionnels n'est **pas stocké** (A17, §8.2).

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
| `locator` | `text` | `NULL` ; `CHECK ((import_batch_id IS NULL) = (locator IS NULL))` |

- Clé primaire `(variable_id, id)` ; toute contrainte d'unicité inclut `variable_id`.
- Index : `(variable_id, entity_id, reference_start_latest)`, `(import_batch_id)`, `(derivation_id) WHERE derivation_id IS NOT NULL`.
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

Une exécution de recalcul vaut pour une date source et une date de géographie : sa table de passage est unique (§9, N5).

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
| `owner_id` | `integer` → `contributor` | |
| `reviewer_id` | `integer` | `NULL` |
| `reviewer_kind` | enum `contributor_kind` | `NULL` |
| `recorded_at` | `timestamptz` | fixé par trigger à `now()` |
| `procedure` | `text` | |
| `scope` | `jsonb` | territoire, période, variables |
| `validation_report` | `jsonb` | `NULL` ; contrôles, comptes, anomalies (A19), échantillon tiré |
| `batch_status` | enum (`proposed`, `validated`, `partially_validated`, `rejected`) | état courant, recopié de la dernière révision du lot |

Vérificateur (réponse A13), entièrement déclaratif :
- clé étrangère `(reviewer_id, reviewer_kind) → contributor (id, contributor_kind)` ;
- `CHECK (reviewer_kind = 'human')` ;
- `CHECK (reviewer_id <> owner_id)` ;
- `CHECK ((reviewer_id IS NULL) = (reviewer_kind IS NULL))` ;
- `CHECK (batch_status = 'proposed' OR (reviewer_id IS NOT NULL AND validation_report IS NOT NULL))`.

Le statut est historisé par les **révisions du lot** (réponse A12). Valider le lot passe au statut `validated` les assertions du lot encore au statut `proposed` (modèle §10.5), ce qui crée leurs révisions ; les observations du lot, elles, ne sont pas réécrites.

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
| `snapshot` | `jsonb` | `NULL` ; état **résultant** : tronc, contenu du type, liens de citation |

Cibles, par `CHECK` :
- révision d'**assertion** : `assertion_id` seul, avec `review_status` et `snapshot` ;
- révision d'**observation** : la paire d'observation seule, avec `review_status` et `snapshot` ;
- révision de **lot** : ni assertion ni observation, `import_batch_id` et `batch_status` renseignés, `snapshot` `NULL`.

Index : `(assertion_id, recorded_at, id)`, `(observation_variable_id, observation_id, recorded_at, id)`, `(import_batch_id, recorded_at, id)`, chacun partiel (`WHERE … IS NOT NULL`).

`previous_content` (modèle §10.1) n'est pas stocké : c'est l'instantané de la révision précédente.

**Mécanique des triggers**
- Toute écriture révisée lit le contexte de la transaction dans des variables `SET LOCAL` : `atlas.contributor_id` (obligatoire), `atlas.reason`, `atlas.import_batch_id`. Si le contributeur manque, l'écriture est refusée.
- **Assertions** : un trigger de contrainte différé, sur `assertion`, les tables de type et `assertion_citation`, écrit au commit **au plus une révision par assertion et par transaction** : il ne fait rien si une révision de cette assertion a déjà ce `recorded_at`. Comme il s'exécute au commit, l'instantané reflète l'état final. L'opération se **déduit** : `create` si l'assertion est née dans la transaction, `review_status_change` si seul le statut a changé, `correct` sinon.
- **Observations** : trigger `AFTER INSERT … WHEN (NEW.import_batch_id IS NULL)` et `AFTER UPDATE`. Une insertion par lot n'appelle **aucune** fonction ligne par ligne : la clause `WHEN` s'évalue sans appel, et la révision du lot vaut pour toutes ses observations (ADR 0003). Une correction ultérieure crée une révision individuelle.
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

---

## 6. Activation du partitionnement des observations

PostgreSQL refuse de créer ou d'attacher une partition tant que la partition par défaut contient des lignes qui lui reviendraient. L'activation pour une variable X se fait donc dans **une seule migration**, exécutée dans une seule transaction (comportement par défaut de dbmate) :

1. **Relever** les comptes de lignes de `observation`, par variable.
2. **Retirer** les clés étrangères qui visent `observation` (`observation_citation`, `derivation_input` ×2, `revision`). PostgreSQL refuse de détacher une partition dont des lignes sont référencées (**à vérifier** en base de développement).
3. `ALTER TABLE observation DETACH PARTITION observation_default`. Les triggers clonés (y compris le refus de suppression) sont retirés de la table détachée. `DETACH … CONCURRENTLY` est interdit en présence d'une partition par défaut, et ne s'exécute pas dans une transaction.
4. **Créer** `observation_v<X>` comme table ordinaire, avec les mêmes colonnes **sans identité** (une partition hérite de l'identité de la table partitionnée et ne peut avoir la sienne), et `CHECK (variable_id = X)`.
5. **Déplacer** : `INSERT INTO observation_v<X> SELECT * FROM observation_default WHERE variable_id = X`, puis `DELETE FROM observation_default WHERE variable_id = X`. Les identifiants sont conservés. Ce déplacement n'est pas une suppression au sens de P7 : les lignes changent de partition, pas de contenu.
6. `ALTER TABLE observation ATTACH PARTITION observation_v<X> FOR VALUES IN (X)` : le `CHECK` de l'étape 4 dispense du parcours de vérification. Index et triggers de ligne sont recréés sur la partition.
7. Ajouter à `observation_default` un `CHECK (variable_id <> ALL (ARRAY[…]))` listant toutes les variables qui ont leur partition, puis la rattacher : `ATTACH PARTITION observation_default DEFAULT`. Le `CHECK` dispense du parcours, mais son ajout parcourt la table une fois.
8. **Rétablir** les clés étrangères de l'étape 2 et les valider.
9. **Vérifier** que les comptes par variable sont égaux à ceux de l'étape 1 ; sinon, la migration échoue et la transaction est annulée.

L'attachement prend un verrou `ACCESS EXCLUSIVE` sur la partition par défaut. La base est donc indisponible en écriture pendant la migration, qui se lance hors des imports.

Le sous-partitionnement (hachage de l'entité, ou zone géographique), nécessaire quand une seule variable dépasse le milliard de lignes, sera tranché par le banc d'essai de l'ADR 0006. **À vérifier** avant la première migration : le comportement des triggers de contrainte différés sur une table partitionnée.

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

Ces révisions ne sont **pas appliquées** : elles le seront après validation, par une modification du document concerné.

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

---

## 9. Points nouveaux soumis à validation

Points qui découlent de la conception et que le modèle ne tranche pas.

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

Non appliqués à `docs/glossaire.md` avant validation (CLAUDE.md, règle 5).

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
