-- Référentiels (docs/schema.md, §5.1) et table nue des événements (§5.5), créée
-- ici parce que le tronc commun des assertions la référence (E1).

-- migrate:up

SET ROLE atlas_owner;

-- Taxonomie ouverte et hiérarchique des entités (modèle §4.2).
CREATE TABLE entity_category (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id smallint REFERENCES entity_category,
  code text NOT NULL UNIQUE,
  label text NOT NULL
);

-- Un contributeur par rôle de connexion (§5.13).
CREATE TABLE contributor (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  contributor_kind contributor_kind NOT NULL,
  display_name text NOT NULL,
  db_role name NOT NULL UNIQUE,
  -- Cible de la clé du vérificateur d'un lot (A13).
  UNIQUE (id, contributor_kind)
);

-- Identité nue (P2) : l'existence se déduit (vue `entity_existence`).
CREATE TABLE entity (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_category_id smallint NOT NULL REFERENCES entity_category
);

-- Identité nue (A3) : type et dates sont des assertions.
CREATE TABLE event (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE division_system (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  authority_entity_id integer NOT NULL REFERENCES entity,
  label text NOT NULL
);

CREATE TABLE level (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  division_system_id smallint NOT NULL REFERENCES division_system,
  label text NOT NULL,
  rank smallint NOT NULL,
  UNIQUE (division_system_id, label)
);

CREATE TABLE registry (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code text NOT NULL UNIQUE,
  authority_entity_id integer REFERENCES entity
);

CREATE TABLE relation_type (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code text NOT NULL UNIQUE
);

CREATE TABLE relation_subtype (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  relation_type_id smallint NOT NULL REFERENCES relation_type,
  code text NOT NULL UNIQUE,
  -- Cible de la clé composite de `relation_assertion` : le sous-type appartient au type.
  UNIQUE (id, relation_type_id)
);

CREATE TABLE event_type (
  id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code text NOT NULL UNIQUE
);

-- La date telle que la source l'écrit (modèle §3.1), bornes en jours juliens.
CREATE TABLE historical_date (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  original_expression text NOT NULL,
  source_calendar source_calendar NOT NULL,
  granularity granularity NOT NULL,
  qualifier qualifier NOT NULL,
  earliest int4 NOT NULL,
  latest int4 NOT NULL,
  conversion_rule text,
  CONSTRAINT historical_date_bounds CHECK (earliest <= latest),
  -- Cibles des clés du motif de période (§3.3) et de `event_date_assertion` (§5.5).
  UNIQUE (id, earliest),
  UNIQUE (id, latest),
  UNIQUE (id, earliest, latest)
);

-- Codes de la tranche 1 (§5.1, E11) ; libellés des catégories validés le 2026-10-17.
INSERT INTO entity_category (code, label) VALUES
  ('political', 'politique'),
  ('administrative', 'administrative'),
  ('statistical', 'statistique'),
  ('cultural', 'culturelle'),
  ('natural', 'naturelle'),
  ('place', 'lieu'),
  ('organization', 'organisation');

INSERT INTO relation_type (code) VALUES ('continuation_of');

INSERT INTO relation_subtype (relation_type_id, code)
SELECT id, subtype
FROM relation_type, unnest(ARRAY['restoration', 'usage_continuity']) AS subtype
WHERE code = 'continuation_of';

-- Types d'événement du glossaire (§5).
INSERT INTO event_type (code) VALUES
  ('creation'),
  ('dissolution'),
  ('restoration'),
  ('merger'),
  ('absorption'),
  ('split'),
  ('cession'),
  ('annexation'),
  ('retrocession'),
  ('renaming'),
  ('legal_status_change'),
  ('boundary_adjustment');

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
