-- Tronc commun des assertions, liens de citation et tables de type sur les entités
-- et les systèmes (docs/schema.md, §3, §5.3, §5.4 et §5.6). Les contrôles qui lisent
-- d'autres tables (P3, autorité, contenu) sont des triggers différés (dernière migration).

-- migrate:up

SET ROLE atlas_owner;

CREATE TABLE assertion (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  assertion_type assertion_type NOT NULL,
  subject_entity_id integer REFERENCES entity,
  subject_event_id integer REFERENCES event,
  subject_division_system_id smallint REFERENCES division_system,

  -- Motif de période (§3), entièrement NULL quand le sujet est un événement (N1).
  start_kind start_kind,
  start_earliest int4,
  start_latest int4,
  start_date_id bigint,
  end_kind end_kind,
  end_earliest int4,
  end_latest int4,
  end_date_id bigint,
  end_latest_dated int4 GENERATED ALWAYS AS (
    CASE WHEN end_kind = 'dated' THEN end_latest END
  ) STORED,
  -- Noyau [début au plus tard, fin au plus tôt[ ; vide si les bornes se croisent.
  core_range int4range GENERATED ALWAYS AS (
    CASE
      WHEN start_kind IS NULL THEN NULL
      WHEN end_earliest <= start_latest THEN 'empty'::int4range
      ELSE int4range(start_latest, end_earliest)
    END
  ) STORED,
  -- Extension maximale [début au plus tôt, fin au plus tard[, borne NULL = non bornée.
  max_range int4range GENERATED ALWAYS AS (
    CASE
      WHEN start_kind IS NULL THEN NULL
      WHEN end_latest <= start_earliest THEN 'empty'::int4range
      ELSE int4range(start_earliest, end_latest)
    END
  ) STORED,

  authority_entity_id integer REFERENCES entity,
  certainty certainty NOT NULL,
  margin numeric,
  opening_event_id integer REFERENCES event,
  closing_event_id integer REFERENCES event,
  review_status review_status NOT NULL DEFAULT 'proposed',

  CONSTRAINT assertion_single_subject CHECK (
    num_nonnulls(subject_entity_id, subject_event_id, subject_division_system_id) = 1
  ),
  CONSTRAINT assertion_subject_matches_type CHECK (
    CASE
      WHEN assertion_type IN ('participation', 'transfer', 'event_type', 'event_date')
        THEN subject_event_id IS NOT NULL
      WHEN assertion_type = 'system_validity' THEN subject_division_system_id IS NOT NULL
      ELSE subject_entity_id IS NOT NULL
    END
  ),

  -- Motif de période (§3.2).
  CONSTRAINT assertion_period_iff_not_event CHECK (
    (subject_event_id IS NULL) = (start_kind IS NOT NULL)
  ),
  CONSTRAINT assertion_period_null_block CHECK (
    start_kind IS NOT NULL
    OR num_nonnulls(
      start_earliest, start_latest, start_date_id, end_kind, end_earliest, end_latest, end_date_id
    ) = 0
  ),
  CONSTRAINT assertion_period_required CHECK (
    start_kind IS NULL
    OR (start_latest IS NOT NULL AND start_date_id IS NOT NULL AND end_kind IS NOT NULL)
  ),
  CONSTRAINT assertion_start_dated CHECK (
    start_kind IS DISTINCT FROM 'dated'
    OR (start_earliest IS NOT NULL AND start_earliest <= start_latest)
  ),
  CONSTRAINT assertion_start_unknown CHECK (
    start_kind IS DISTINCT FROM 'unknown' OR start_earliest IS NULL
  ),
  CONSTRAINT assertion_end_dated CHECK (
    end_kind IS DISTINCT FROM 'dated'
    OR (
      end_earliest IS NOT NULL
      AND end_latest IS NOT NULL
      AND end_date_id IS NOT NULL
      AND end_earliest <= end_latest
    )
  ),
  CONSTRAINT assertion_end_ongoing CHECK (
    end_kind IS DISTINCT FROM 'ongoing'
    OR (end_earliest IS NULL AND end_latest IS NULL AND end_date_id IS NULL)
  ),
  CONSTRAINT assertion_end_unknown CHECK (
    end_kind IS DISTINCT FROM 'unknown'
    OR (
      end_earliest IS NOT NULL
      AND end_date_id IS NOT NULL
      AND (end_latest IS NULL OR end_latest >= end_earliest)
    )
  ),
  CONSTRAINT assertion_period_order CHECK (
    start_earliest IS NULL OR end_latest IS NULL OR start_earliest < end_latest
  ),

  -- Accord des bornes avec les dates historiques (§3.3), MATCH SIMPLE.
  CONSTRAINT assertion_start_latest_fkey FOREIGN KEY (start_date_id, start_latest)
    REFERENCES historical_date (id, latest),
  CONSTRAINT assertion_start_earliest_fkey FOREIGN KEY (start_date_id, start_earliest)
    REFERENCES historical_date (id, earliest),
  CONSTRAINT assertion_end_earliest_fkey FOREIGN KEY (end_date_id, end_earliest)
    REFERENCES historical_date (id, earliest),
  CONSTRAINT assertion_end_latest_fkey FOREIGN KEY (end_date_id, end_latest_dated)
    REFERENCES historical_date (id, latest),

  -- Cibles des tables de type et de la copie de `external_id_assertion`.
  UNIQUE (id, assertion_type),
  UNIQUE (id, assertion_type, subject_entity_id, core_range, review_status)
);

CREATE INDEX ON assertion (subject_entity_id, assertion_type);
CREATE INDEX ON assertion (subject_event_id, assertion_type);
CREATE INDEX ON assertion (subject_division_system_id);
CREATE INDEX ON assertion (authority_entity_id);
CREATE INDEX ON assertion USING gist (core_range);

CREATE TABLE assertion_citation (
  assertion_id bigint NOT NULL REFERENCES assertion,
  citation_id bigint NOT NULL REFERENCES citation,
  citation_role citation_role NOT NULL,
  PRIMARY KEY (assertion_id, citation_id, citation_role)
);

CREATE INDEX ON assertion_citation (citation_id);

-- Tables de type (§5.4) : clé primaire `id`, type fixé, clé (id, assertion_type).

CREATE TABLE name_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'name' CHECK (assertion_type = 'name'),
  text text NOT NULL,
  language text NOT NULL,
  script text NOT NULL,
  transliteration text,
  name_type name_type NOT NULL,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

CREATE INDEX ON name_assertion (text);

-- Les colonnes copiées du tronc (sujet, noyau, statut) sont renseignées par trigger
-- et tenues à jour par la clé ON UPDATE CASCADE.
CREATE TABLE external_id_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'external_id'
    CHECK (assertion_type = 'external_id'),
  registry_id smallint NOT NULL REFERENCES registry,
  object_type text,
  code text NOT NULL,
  subject_entity_id integer NOT NULL,
  core_range int4range NOT NULL,
  review_status review_status NOT NULL,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type),
  CONSTRAINT external_id_assertion_trunk_copy_fkey
    FOREIGN KEY (id, assertion_type, subject_entity_id, core_range, review_status)
    REFERENCES assertion (id, assertion_type, subject_entity_id, core_range, review_status)
    ON UPDATE CASCADE,
  -- Un code d'un référentiel ne désigne qu'une entité à une date (A11, N11).
  CONSTRAINT external_id_assertion_code_unique EXCLUDE USING gist (
    registry_id WITH =,
    (coalesce(object_type, '')) WITH =,
    code WITH =,
    core_range WITH &&,
    subject_entity_id WITH <>
  ) WHERE (review_status <> 'withdrawn')
);

CREATE INDEX ON external_id_assertion (registry_id, object_type, code);

CREATE TABLE legal_status_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'legal_status'
    CHECK (assertion_type = 'legal_status'),
  legal_status text NOT NULL,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

CREATE TABLE system_membership_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'system_membership'
    CHECK (assertion_type = 'system_membership'),
  level_id smallint NOT NULL REFERENCES level,
  parent_entity_id integer REFERENCES entity,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

CREATE INDEX ON system_membership_assertion (level_id);
CREATE INDEX ON system_membership_assertion (parent_entity_id);

CREATE TABLE relation_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'relation' CHECK (assertion_type = 'relation'),
  relation_type_id smallint NOT NULL REFERENCES relation_type,
  relation_subtype_id smallint,
  target_entity_id integer NOT NULL REFERENCES entity,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type),
  FOREIGN KEY (relation_subtype_id, relation_type_id)
    REFERENCES relation_subtype (id, relation_type_id)
);

CREATE INDEX ON relation_assertion (target_entity_id);

-- Contenu immuable (trigger de la dernière migration) ; validité OGC contrôlée par le lot.
CREATE TABLE geometry_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'geometry' CHECK (assertion_type = 'geometry'),
  shape geometry(Geometry, 4326) NOT NULL
    CONSTRAINT geometry_assertion_shape_type
    CHECK (GeometryType(shape) IN ('POLYGON', 'MULTIPOLYGON', 'POINT', 'LINESTRING')),
  spatial_accuracy numeric,
  resolution integer,
  method geometry_method NOT NULL,
  source_crs text NOT NULL,
  parent_geometry_id bigint REFERENCES geometry_assertion,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

CREATE INDEX ON geometry_assertion USING gist (shape);

-- Validité d'un système de découpage (A16) : seule la période du tronc compte.
CREATE TABLE system_validity_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'system_validity'
    CHECK (assertion_type = 'system_validity'),
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
