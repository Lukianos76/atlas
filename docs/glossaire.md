# Glossaire du code

> **Statut** : version 1 (octobre 2026), validée.
> **Portée** : traduction anglaise des termes de `docs/modele-donnees.md`, de `docs/politique-editoriale.md` et des ADR, pour les identifiants du code, du schéma et des fichiers publiés (CLAUDE.md, règle 5). Les commentaires et la documentation restent en français.
> **Règle** : un terme absent de ce glossaire n'est pas traduit à la volée. Sa traduction est proposée pour ajout.

---

## 1. Conventions

- **Casse** : chaque langage garde sa casse habituelle. On écrit `snake_case` en SQL et en Python, `camelCase` pour les champs TypeScript et `PascalCase` pour les types. Le glossaire donne la forme `snake_case`.
- **Orthographe** : anglais américain (`license`, `normalize`).
- **Ce qui ne se traduit pas** :
  - les **valeurs de données** issues des sources : noms de niveaux, de statuts juridiques et de catégories fines (« commune », « Bezirk », « Reichsland »). Ce sont des contenus d'assertions, pas des identifiants ;
  - le **vocabulaire des référentiels externes** : `COM`, `COMA`, `COMD`, `ARM`, les codes de type de modification du COG, `INSEE`, `NUTS`, `LAU` ;
  - les noms propres.
- **Collisions évitées** : plusieurs termes français ont deux sens dans le modèle, ou un sens qui entre en conflit avec PostgreSQL. Ils sont signalés par ⚠.

---

## 2. Principes et temps

| Français | Anglais | Note |
|---|---|---|
| entité | `entity` | |
| catégorie d'entité | `entity_category` | |
| identifiant interne | `id` | |
| assertion | `assertion` | |
| assertions concurrentes | `competing_assertions` | |
| date historique | `historical_date` | |
| expression originale | `original_expression` | |
| calendrier d'origine | `source_calendar` | |
| précision (granularité d'une date) | `granularity` | ⚠ distinct de la marge (§3) |
| au plus tôt / au plus tard | `earliest` / `latest` | |
| qualificatif (exact, environ, avant, après, présumé) | `qualifier` (`exact`, `approximate`, `before`, `after`, `presumed`) | |
| période | `period` | |
| période de validité | `validity_period` | |
| noyau (d'une période) | `core_range` | ADR 0003 |
| extension maximale (d'une période) | `max_range` | ADR 0003 |
| nature du début / de la fin | `start_kind` / `end_kind` | |
| datée, en cours, inconnue | `dated`, `ongoing`, `unknown` | |
| jour julien | `julian_day` | |
| temps de validité | `valid_time` | Terme standard de la bitemporalité |
| temps d'enregistrement, date d'enregistrement R | `transaction_time` | Forme avec `valid_time` la paire standard de la bitemporalité |

## 3. Assertions

| Français | Anglais | Note |
|---|---|---|
| sujet | `subject` | |
| contenu | `content` | |
| autorité | `authority` | |
| certitude | `certainty` | |
| établi, probable, possible, conjectural | `established`, `probable`, `possible`, `conjectural` | |
| précision (marge numérique) | `margin` | ⚠ distinct de `granularity` |
| événement d'origine / de fin | `opening_event` / `closing_event` | |
| nom | `name` | |
| texte, langue, écriture, translittération | `text`, `language`, `script`, `transliteration` | |
| type de nom | `name_type` | |
| officiel, endonyme, exonyme, historique, usuel, abrégé | `official`, `endonym`, `exonym`, `historical`, `common`, `abbreviated` | |
| identifiant externe | `external_id` | |
| référentiel | `registry` | |
| type d'objet | `object_type` | |
| code | `code` | |
| statut (nature juridique) | `legal_status` | ⚠ distinct du statut de révision (§8) |
| relation | `relation` | |
| type de relation | `relation_type` | |

**Types de relation**

| Français | Anglais |
|---|---|
| `appartient_a` | `member_of` |
| `souverainete_revendiquee_par` | `sovereignty_claimed_by` |
| `controle_de_fait_par` | `de_facto_controlled_by` |
| `reconnait` | `recognizes` |
| `est_continuation_de` | `continuation_of` |
| rétablissement, continuité d'usage (sous-types) | `restoration`, `usage_continuity` |
| `voisin_de`, `capitale_de` | `neighbor_of`, `capital_of` |

## 4. Découpages et géométries

| Français | Anglais | Note |
|---|---|---|
| système de découpage | `division_system` | |
| niveau | `level` | |
| appartenance à un système | `system_membership` | |
| entité parente | `parent` | |
| géométrie | `geometry` | |
| forme | `shape` | |
| zone floue | `fuzzy_zone` | |
| cœur / extension maximale (d'une zone floue) | `core` / `max_extent` | |
| précision spatiale | `spatial_accuracy` | En mètres |
| résolution | `resolution` | |
| méthode : levé officiel, numérisation, reconstitution, dérivation, estimation | `method` : `official_survey`, `digitization`, `reconstruction`, `derivation`, `estimate` | |
| géométrie parente | `parent_geometry` | |
| frontière | `boundary` | Plus neutre que `border` |
| type de frontière | `boundary_type` | |
| anomalie | `anomaly` | |
| chevauchement, lacune, débordement | `overlap`, `gap`, `outside_parent` | |

## 5. Événements, transferts, filiation

| Français | Anglais | Note |
|---|---|---|
| événement | `event` | |
| événement territorial | `territorial_event` | |
| participation | `participation` | |
| rôle : `cree`, `supprime`, `concerne`, `acteur` | `role` : `created`, `dissolved`, `affected`, `actor` | ⚠ `dissolved` plutôt que `deleted`, pour ne pas évoquer une suppression en base |
| récit | `narrative` | |
| création, suppression, rétablissement | `creation`, `dissolution`, `restoration` | |
| fusion, absorption, scission | `merger`, `absorption`, `split` | |
| cession, annexion, rétrocession | `cession`, `annexation`, `retrocession` | |
| changement de nom, de statut | `renaming`, `legal_status_change` | ⚠ distinct de `review_status_change` (§8) |
| rectification de limite | `boundary_adjustment` | |
| mouvement du COG | `cog_movement` | Ligne ou groupe de lignes de la table des mouvements ; ce n'est pas un `event` (modèle, §7.4) |
| transfert | `transfer` | |
| source / destination d'un transfert | `from_entity` / `to_entity` | ⚠ évite `source`, réservé aux sources citées |
| territoire transféré | `territory` | |
| part | `share` | |
| filiation | `lineage` | |
| graphe de filiation | `lineage_graph` | |
| table de passage | `crosswalk` | Terme usuel en statistique |

## 6. Observations et dérivations

| Français | Anglais | Note |
|---|---|---|
| variable | `variable` | |
| règle d'agrégation : additive, non additive | `aggregation_rule` : `additive`, `non_additive` | |
| dimension | `dimension` | |
| membre de dimension | `dimension_member` | |
| observation | `observation` | |
| rôle d'entité : sujet, origine, destination, zone de référence | `entity_role` : `subject`, `origin`, `destination`, `reference_area` | |
| période de référence | `reference_period` | |
| valeur, marge | `value`, `margin` | |
| nature : originale, dérivée | `nature` : `original`, `derived` | |
| date de géographie | `geography_date` | |
| géographie courante | `current_geography` | ⚠ seul emploi de `current` ; un état matérialisé à jour est `up_to_date` (§9) |
| dérivation interne, externe | `derivation` : `internal`, `external` | |
| auteur | `author` | |
| entrées | `inputs` | |
| somme simple, pondération surfacique, pondération par la population, interpolation | `simple_sum`, `area_weighting`, `population_weighting`, `interpolation` | |
| avertissement | `caveat` | |
| correspondance entre variables | `variable_mapping` | |

## 7. Sources

| Français | Anglais | Note |
|---|---|---|
| œuvre source | `source_work` | |
| type de source : primaire, secondaire, dérivée | `source_type` : `primary`, `secondary`, `derived` | |
| titre, auteurs, éditeur | `title`, `authors`, `publisher` | |
| date de publication | `publication_date` | |
| version, édition, millésime | `version`, `edition`, `vintage` | `vintage` pour le millésime d'un jeu de données |
| identifiants pérennes | `persistent_ids` | |
| licence | `license` | |
| fiabilité éditoriale | `editorial_reliability` | |
| citation | `citation` | |
| localisateur | `locator` | |
| URL consultée, date de consultation | `accessed_url`, `accessed_on` | |
| copie archivée | `archived_copy` | |
| extrait | `excerpt` | |
| rôle de la citation | `citation_role` | |

## 8. Contribution et modération

| Français | Anglais | Note |
|---|---|---|
| révision | `revision` | |
| contributeur | `contributor` | |
| horodatage | `recorded_at` | |
| opération : création, correction, changement de statut | `operation` : `create`, `correct`, `review_status_change` | ⚠ distinct de `legal_status_change` (§5) |
| statut de révision | `review_status` | ⚠ distinct de `legal_status` |
| proposée, validée, contestée, retirée | `proposed`, `validated`, `contested`, `withdrawn` | ⚠ `contested` (révision) ≠ `disputed` (territoire) |
| motif | `reason` | |
| contenu précédent | `previous_content` | |
| lot d'import | `import_batch` | |
| responsable du lot | `owner` | |
| procédure | `procedure` | |
| périmètre | `scope` | |
| rapport de validation | `validation_report` | |
| échantillon | `sample` | |
| statut du lot : proposé, validé, partiellement validé, rejeté | `batch_status` : `proposed`, `validated`, `partially_validated`, `rejected` | |
| erratum | `erratum` | |

## 9. Points de vue, affichage, publication

| Français | Anglais | Note |
|---|---|---|
| point de vue | `viewpoint` | |
| règle de sélection | `selection_rule` | |

**Points de vue** : liste fermée de `docs/politique-editoriale.md` §2.4. Toute révision de cette liste ajoute ici son identifiant.

| Français | Anglais |
|---|---|
| par défaut de l'atlas | `atlas_default` |
| contrôle de fait | `de_facto_control` |
| souveraineté de droit | `de_jure_sovereignty` |
| position d'une entité politique | `political_entity_position` |

| Français | Anglais | Note |
|---|---|---|
| préférence | `preference` | |
| assertion retenue | `selected_assertion` | |
| justification | `rationale` | |
| état matérialisé | `materialized_state` | ⚠ à ne pas confondre avec une vue matérialisée PostgreSQL |
| obsolète, à jour | `stale`, `up_to_date` | ⚠ pas `current`, réservé à `current_geography` |
| disputé | `disputed` | |
| non tranché | `unresolved` | |
| sources divergentes | `conflicting_sources` | |
| publication | `publication` | ADR 0004 |
| identifiant de publication | `publication_id` | |
| manifeste | `manifest` | ADR 0009 |
| empreinte | `checksum` | |

---

## 10. Choix tranchés (version 1)

| # | Question | Retenu | Écarté |
|---|---|---|---|
| G1 | Temps d'enregistrement | `transaction_time` | `record_time` |
| G2 | Référentiel d'identifiants | `registry` | `reference_system`, `code_list` |
| G3 | Rôle `supprime` et événement de suppression | `dissolved`, `dissolution` | `abolished`, `abolition` |
| G4 | Extrémités d'un transfert | `from_entity` / `to_entity` | `source` / `target` (collision avec les sources citées) |
| G5 | Point de vue | `viewpoint` | `perspective`, `point_of_view` |
| G6 | État matérialisé | `materialized_state` | `resolved_state`, `snapshot` |
| G7 | Lot d'import | `import_batch` | `batch` seul |
| G8 | Table de passage | `crosswalk` | `correspondence_table` |
| G9 | Millésime | `vintage` | `release_year` |

Corrections de la validation : `status_change` scindé en `legal_status_change` et `review_status_change` ; `current` remplacé par `up_to_date` pour l'état matérialisé ; points de vue alignés sur la politique éditoriale (§2.4) ; ajout de `current_geography` et `cog_movement`.
