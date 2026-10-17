-- Lots d'import, révisions et vues déduites (docs/schema.md, §5.10 à §5.12).

-- migrate:up

SET ROLE atlas_owner;

-- Lot d'import (modèle §10.5). Responsable et vérificateur sont fixés par trigger à
-- partir de `current_user` (E4, §5.13) ; gel de la procédure, du périmètre et du
-- rapport par trigger (dernière migration).
CREATE TABLE import_batch (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  citation_id bigint NOT NULL REFERENCES citation,
  owner_id integer NOT NULL REFERENCES contributor,
  reviewer_id integer,
  reviewer_kind contributor_kind,
  recorded_at timestamptz NOT NULL,
  procedure text NOT NULL,
  scope jsonb NOT NULL,
  validation_report jsonb,
  batch_status batch_status NOT NULL DEFAULT 'proposed',
  -- Vérificateur (A13), entièrement déclaratif.
  CONSTRAINT import_batch_reviewer_fkey FOREIGN KEY (reviewer_id, reviewer_kind)
    REFERENCES contributor (id, contributor_kind),
  CONSTRAINT import_batch_reviewer_human CHECK (reviewer_kind = 'human'),
  CONSTRAINT import_batch_reviewer_not_owner CHECK (reviewer_id <> owner_id),
  CONSTRAINT import_batch_reviewer_pair CHECK ((reviewer_id IS NULL) = (reviewer_kind IS NULL)),
  CONSTRAINT import_batch_decision CHECK (
    batch_status = 'proposed' OR (reviewer_id IS NOT NULL AND validation_report IS NOT NULL)
  )
);

ALTER TABLE observation
  ADD CONSTRAINT observation_import_batch_fkey
  FOREIGN KEY (import_batch_id) REFERENCES import_batch;

-- Journal en ajout seul (D4) : lignes écrites par les triggers uniquement.
CREATE TABLE revision (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  recorded_at timestamptz NOT NULL,
  contributor_id integer NOT NULL REFERENCES contributor,
  operation operation NOT NULL,
  review_status review_status,
  batch_status batch_status,
  reason text,
  import_batch_id integer REFERENCES import_batch,
  assertion_id bigint REFERENCES assertion,
  observation_variable_id integer,
  observation_id bigint,
  snapshot jsonb,
  FOREIGN KEY (observation_variable_id, observation_id) REFERENCES observation (variable_id, id),
  CONSTRAINT revision_observation_pair CHECK (
    num_nonnulls(observation_variable_id, observation_id) IN (0, 2)
  ),
  -- Cibles : assertion, observation ou lot (§5.11).
  CONSTRAINT revision_target CHECK (
    (
      assertion_id IS NOT NULL
      AND observation_id IS NULL
      AND review_status IS NOT NULL
      AND batch_status IS NULL
      AND snapshot IS NOT NULL
    )
    OR (
      observation_id IS NOT NULL
      AND assertion_id IS NULL
      AND review_status IS NOT NULL
      AND batch_status IS NULL
      AND snapshot IS NOT NULL
    )
    OR (
      assertion_id IS NULL
      AND observation_id IS NULL
      AND import_batch_id IS NOT NULL
      AND review_status IS NULL
      AND batch_status IS NOT NULL
      AND snapshot IS NULL
    )
  ),
  -- Motif obligatoire pour une correction, un retrait ou un rejet (modèle §10.1).
  CONSTRAINT revision_reason_required CHECK (
    reason IS NOT NULL
    OR NOT (
      operation = 'correct'
      OR review_status IS NOT DISTINCT FROM 'withdrawn'
      OR batch_status IS NOT DISTINCT FROM 'rejected'
    )
  )
);

CREATE INDEX ON revision (assertion_id, recorded_at, id) WHERE assertion_id IS NOT NULL;
CREATE INDEX ON revision (observation_variable_id, observation_id, recorded_at, id)
  WHERE observation_id IS NOT NULL;
CREATE INDEX ON revision (import_batch_id, recorded_at, id) WHERE import_batch_id IS NOT NULL;

-- Période de transaction [recorded_at, superseded_at[ de chaque révision (D4, §5.12).
CREATE VIEW revision_period AS
SELECT
  r.*,
  lead(r.recorded_at) OVER (
    PARTITION BY
      r.assertion_id,
      r.observation_variable_id,
      r.observation_id,
      CASE WHEN r.batch_status IS NOT NULL THEN r.import_batch_id END
    ORDER BY r.recorded_at, r.id
  ) AS superseded_at
FROM revision AS r;

-- Statut d'une observation au temps R (§5.12, N4) : sa dernière révision individuelle,
-- à défaut la dernière révision de son lot, avec la correspondance des statuts.
CREATE FUNCTION observation_review_status(
  p_variable_id integer,
  p_observation_id bigint,
  p_at timestamptz DEFAULT now()
) RETURNS review_status
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
    (
      SELECT r.review_status
      FROM revision AS r
      WHERE r.observation_variable_id = p_variable_id
        AND r.observation_id = p_observation_id
        AND r.recorded_at <= p_at
      ORDER BY r.recorded_at DESC, r.id DESC
      LIMIT 1
    ),
    (
      SELECT
        CASE r.batch_status
          WHEN 'proposed' THEN 'proposed'
          WHEN 'validated' THEN 'validated'
          WHEN 'partially_validated' THEN 'validated'
          WHEN 'rejected' THEN 'withdrawn'
        END::review_status
      FROM observation AS o
      JOIN revision AS r ON r.import_batch_id = o.import_batch_id AND r.batch_status IS NOT NULL
      WHERE o.variable_id = p_variable_id
        AND o.id = p_observation_id
        AND r.recorded_at <= p_at
      ORDER BY r.recorded_at DESC, r.id DESC
      LIMIT 1
    )
  )
$$;

-- Existence d'une entité, déduite (A1, §5.12). Plusieurs participations concurrentes
-- donnent plusieurs lignes.
CREATE VIEW entity_existence AS
WITH effective_date AS (
  -- Date d'effet, non retirée, de chaque participation non retirée.
  SELECT p.entity_id, p.role, d.date_id, d.earliest, d.latest
  FROM participation_assertion AS p
  JOIN assertion AS pa ON pa.id = p.id AND pa.review_status <> 'withdrawn'
  JOIN assertion AS da
    ON da.subject_event_id = pa.subject_event_id
    AND da.assertion_type = 'event_date'
    AND da.review_status <> 'withdrawn'
  JOIN event_date_assertion AS d ON d.id = da.id AND d.event_date_kind = 'effective'
  WHERE p.role IN ('created', 'dissolved')
),
attestation AS (
  -- Première et dernière attestation, et fin `ongoing` affirmée.
  SELECT
    a.subject_entity_id AS entity_id,
    min(a.start_latest) AS first_attested,
    max(a.end_earliest) AS last_attested,
    bool_or(a.end_kind = 'ongoing') AS ongoing
  FROM assertion AS a
  WHERE a.subject_entity_id IS NOT NULL AND a.review_status <> 'withdrawn'
  GROUP BY a.subject_entity_id
),
existence_start AS (
  SELECT entity_id, 'dated'::start_kind AS start_kind, earliest AS start_earliest,
    latest AS start_latest
  FROM effective_date
  WHERE role = 'created'
  UNION ALL
  SELECT t.entity_id, 'unknown', NULL, t.first_attested
  FROM attestation AS t
  WHERE NOT EXISTS (
    SELECT FROM effective_date AS e WHERE e.entity_id = t.entity_id AND e.role = 'created'
  )
),
existence_end AS (
  SELECT entity_id, 'dated'::end_kind AS end_kind, earliest AS end_earliest,
    latest AS end_latest
  FROM effective_date
  WHERE role = 'dissolved'
  UNION ALL
  SELECT
    t.entity_id,
    CASE WHEN t.ongoing THEN 'ongoing' ELSE 'unknown' END::end_kind,
    CASE WHEN t.ongoing THEN NULL ELSE t.last_attested END,
    NULL
  FROM attestation AS t
  WHERE NOT EXISTS (
    SELECT FROM effective_date AS e WHERE e.entity_id = t.entity_id AND e.role = 'dissolved'
  )
)
SELECT
  s.entity_id,
  s.start_kind,
  s.start_earliest,
  s.start_latest,
  e.end_kind,
  e.end_earliest,
  e.end_latest
FROM existence_start AS s
JOIN existence_end AS e USING (entity_id);

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
