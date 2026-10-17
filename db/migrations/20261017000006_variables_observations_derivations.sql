-- Variables, dérivations et observations (docs/schema.md, §5.7 à §5.9 et §6).
-- La clé `observation.import_batch_id → import_batch` est ajoutée avec les lots (E1).

-- migrate:up

SET ROLE atlas_owner;

CREATE TABLE variable (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  label text NOT NULL,
  definition text NOT NULL,
  unit text NOT NULL,
  method text,
  value_type value_type NOT NULL,
  aggregation_rule aggregation_rule NOT NULL,
  class_breaks numeric[],
  class_breaks_rationale text,
  CONSTRAINT variable_class_breaks_rationale CHECK (
    (class_breaks IS NULL) = (class_breaks_rationale IS NULL)
  )
);

-- Partagée par les observations d'une même exécution (A8) ; immuable.
CREATE TABLE derivation (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  derivation_kind derivation_kind NOT NULL,
  author_entity_id integer REFERENCES entity,
  method derivation_method,
  method_citation_id bigint REFERENCES citation,
  method_summary text,
  inputs_description text,
  caveat text,
  contributor_id integer NOT NULL REFERENCES contributor,
  recorded_at timestamptz NOT NULL,
  CONSTRAINT derivation_author CHECK (
    (derivation_kind = 'internal') = (author_entity_id IS NULL)
  ),
  CONSTRAINT derivation_internal_method CHECK (
    derivation_kind <> 'internal' OR method IS NOT NULL
  ),
  -- Une méthode externe est citée (modèle §8.4).
  CONSTRAINT derivation_external_citation CHECK (
    derivation_kind <> 'external' OR method_citation_id IS NOT NULL
  )
);

-- Partitionnée par variable (D5) ; une seule partition par défaut en tranche 1.
CREATE TABLE observation (
  id bigint GENERATED ALWAYS AS IDENTITY,
  variable_id integer NOT NULL REFERENCES variable,
  entity_id integer NOT NULL REFERENCES entity,
  entity_role entity_role NOT NULL
    CONSTRAINT observation_entity_role_subject CHECK (entity_role = 'subject'),

  -- Période de référence (A5), motif de période préfixé `reference_`.
  reference_start_kind start_kind NOT NULL,
  reference_start_earliest int4,
  reference_start_latest int4 NOT NULL,
  reference_start_date_id bigint NOT NULL,
  reference_end_kind end_kind NOT NULL,
  reference_end_earliest int4,
  reference_end_latest int4,
  reference_end_date_id bigint,
  reference_end_latest_dated int4 GENERATED ALWAYS AS (
    CASE WHEN reference_end_kind = 'dated' THEN reference_end_latest END
  ) STORED,
  reference_core_range int4range GENERATED ALWAYS AS (
    CASE
      WHEN reference_end_earliest <= reference_start_latest THEN 'empty'::int4range
      ELSE int4range(reference_start_latest, reference_end_earliest)
    END
  ) STORED,
  reference_max_range int4range GENERATED ALWAYS AS (
    CASE
      WHEN reference_end_latest <= reference_start_earliest THEN 'empty'::int4range
      ELSE int4range(reference_start_earliest, reference_end_latest)
    END
  ) STORED,

  value numeric NOT NULL,
  margin numeric,
  nature nature NOT NULL,
  geography_date int4,
  derivation_id integer REFERENCES derivation,
  certainty certainty NOT NULL,
  authority_entity_id integer REFERENCES entity,
  import_batch_id integer,
  locator text CONSTRAINT observation_locator_not_empty CHECK (locator <> ''),

  PRIMARY KEY (variable_id, id),
  -- Import rejouable : une cellule de la source ne produit qu'une observation par lot.
  CONSTRAINT observation_batch_locator_key UNIQUE (variable_id, import_batch_id, locator),

  CONSTRAINT observation_derived_geography_date CHECK (
    (nature = 'derived') = (geography_date IS NOT NULL)
  ),
  CONSTRAINT observation_derived_derivation CHECK (
    (nature = 'derived') = (derivation_id IS NOT NULL)
  ),
  -- P3 pour les observations importées : lot et localisateur ensemble (D3).
  CONSTRAINT observation_batch_locator CHECK ((import_batch_id IS NULL) = (locator IS NULL)),

  -- Motif de période (§3.2).
  CONSTRAINT observation_start_dated CHECK (
    reference_start_kind <> 'dated'
    OR (
      reference_start_earliest IS NOT NULL
      AND reference_start_earliest <= reference_start_latest
    )
  ),
  CONSTRAINT observation_start_unknown CHECK (
    reference_start_kind <> 'unknown' OR reference_start_earliest IS NULL
  ),
  CONSTRAINT observation_end_dated CHECK (
    reference_end_kind <> 'dated'
    OR (
      reference_end_earliest IS NOT NULL
      AND reference_end_latest IS NOT NULL
      AND reference_end_date_id IS NOT NULL
      AND reference_end_earliest <= reference_end_latest
    )
  ),
  CONSTRAINT observation_end_ongoing CHECK (
    reference_end_kind <> 'ongoing'
    OR (
      reference_end_earliest IS NULL
      AND reference_end_latest IS NULL
      AND reference_end_date_id IS NULL
    )
  ),
  CONSTRAINT observation_end_unknown CHECK (
    reference_end_kind <> 'unknown'
    OR (
      reference_end_earliest IS NOT NULL
      AND reference_end_date_id IS NOT NULL
      AND (reference_end_latest IS NULL OR reference_end_latest >= reference_end_earliest)
    )
  ),
  CONSTRAINT observation_period_order CHECK (
    reference_start_earliest IS NULL
    OR reference_end_latest IS NULL
    OR reference_start_earliest < reference_end_latest
  ),
  CONSTRAINT observation_start_latest_fkey
    FOREIGN KEY (reference_start_date_id, reference_start_latest)
    REFERENCES historical_date (id, latest),
  CONSTRAINT observation_start_earliest_fkey
    FOREIGN KEY (reference_start_date_id, reference_start_earliest)
    REFERENCES historical_date (id, earliest),
  CONSTRAINT observation_end_earliest_fkey
    FOREIGN KEY (reference_end_date_id, reference_end_earliest)
    REFERENCES historical_date (id, earliest),
  CONSTRAINT observation_end_latest_fkey
    FOREIGN KEY (reference_end_date_id, reference_end_latest_dated)
    REFERENCES historical_date (id, latest)
) PARTITION BY LIST (variable_id);

CREATE TABLE observation_default PARTITION OF observation DEFAULT;

CREATE INDEX ON observation (variable_id, entity_id, reference_start_latest);
CREATE INDEX ON observation (derivation_id) WHERE derivation_id IS NOT NULL;

CREATE TABLE observation_citation (
  variable_id integer NOT NULL,
  observation_id bigint NOT NULL,
  citation_id bigint NOT NULL REFERENCES citation,
  citation_role citation_role NOT NULL,
  PRIMARY KEY (variable_id, observation_id, citation_id, citation_role),
  FOREIGN KEY (variable_id, observation_id) REFERENCES observation (variable_id, id)
);

-- Entrées d'une dérivation, liées par observation (A8) ; immuables.
CREATE TABLE derivation_input (
  variable_id integer NOT NULL,
  observation_id bigint NOT NULL,
  input_variable_id integer NOT NULL,
  input_observation_id bigint NOT NULL,
  PRIMARY KEY (variable_id, observation_id, input_variable_id, input_observation_id),
  FOREIGN KEY (variable_id, observation_id) REFERENCES observation (variable_id, id),
  FOREIGN KEY (input_variable_id, input_observation_id) REFERENCES observation (variable_id, id)
);

CREATE INDEX ON derivation_input (input_variable_id, input_observation_id);

-- Table de passage d'une exécution (N5) ; immuable.
CREATE TABLE crosswalk (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  derivation_id integer NOT NULL REFERENCES derivation,
  from_entity_id integer NOT NULL REFERENCES entity,
  to_entity_id integer NOT NULL REFERENCES entity,
  share numeric CONSTRAINT crosswalk_share_range CHECK (share > 0 AND share <= 1),
  UNIQUE (derivation_id, from_entity_id, to_entity_id)
);

-- Transferts composés, source des parts (citation par transitivité) ; immuable.
CREATE TABLE crosswalk_transfer (
  crosswalk_id bigint NOT NULL REFERENCES crosswalk,
  transfer_assertion_id bigint NOT NULL REFERENCES transfer_assertion,
  PRIMARY KEY (crosswalk_id, transfer_assertion_id)
);

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
