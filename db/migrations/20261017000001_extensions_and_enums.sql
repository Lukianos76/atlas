-- Extensions, rôles de groupe et types énumérés (docs/schema.md, §1, §5.13 et §8.5).
-- Les extensions sont créées par le superutilisateur (PostGIS l'exige) ; tout le
-- reste du schéma est créé sous le rôle propriétaire `atlas_owner` (E2).

-- migrate:up

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Rôles de groupe (§5.13). Les rôles sont communs à toutes les bases du serveur :
-- un rôle déjà créé pour une autre base n'est pas recréé (E3).
DO $$
DECLARE
  group_role text;
BEGIN
  FOREACH group_role IN ARRAY ARRAY['atlas_owner', 'atlas_import', 'atlas_review'] LOOP
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = group_role) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', group_role);
    END IF;
  END LOOP;
END
$$;

GRANT CREATE ON SCHEMA public TO atlas_owner;

SET ROLE atlas_owner;

-- Motif de période (§3.1).
CREATE TYPE start_kind AS ENUM ('dated', 'unknown');
CREATE TYPE end_kind AS ENUM ('dated', 'ongoing', 'unknown');

-- Dates historiques (§5.1).
CREATE TYPE source_calendar AS ENUM ('gregorian', 'julian', 'french_republican');
CREATE TYPE granularity AS ENUM ('day', 'month', 'year', 'decade', 'century', 'millennium');
CREATE TYPE qualifier AS ENUM ('exact', 'approximate', 'before', 'after', 'presumed');

-- Contributeurs, sources, citations (§5.1, §5.2, §5.3).
CREATE TYPE contributor_kind AS ENUM ('human', 'agent');
CREATE TYPE source_type AS ENUM ('primary', 'secondary', 'derived');
CREATE TYPE citation_role AS ENUM ('value', 'date', 'geometry', 'share');

-- Assertions (§5.3 à §5.6).
CREATE TYPE assertion_type AS ENUM (
  'name',
  'external_id',
  'legal_status',
  'system_membership',
  'relation',
  'geometry',
  'system_validity',
  'event_type',
  'event_date',
  'participation',
  'transfer'
);
CREATE TYPE certainty AS ENUM ('established', 'probable', 'possible', 'conjectural');
CREATE TYPE review_status AS ENUM ('proposed', 'validated', 'contested', 'withdrawn');
CREATE TYPE name_type AS ENUM (
  'official', 'endonym', 'exonym', 'historical', 'common', 'abbreviated'
);
CREATE TYPE geometry_method AS ENUM (
  'official_survey', 'digitization', 'reconstruction', 'derivation', 'estimate'
);

-- Événements (§5.5).
CREATE TYPE event_date_kind AS ENUM ('effective', 'act', 'signature', 'entry_into_force');
CREATE TYPE participation_role AS ENUM ('created', 'dissolved', 'affected', 'actor');
CREATE TYPE territory AS ENUM ('whole', 'partial');
CREATE TYPE share_basis AS ENUM ('area', 'population');

-- Variables, observations, dérivations (§5.7 à §5.9).
CREATE TYPE value_type AS ENUM ('quantity', 'rate', 'category', 'text');
CREATE TYPE aggregation_rule AS ENUM ('additive', 'non_additive');
CREATE TYPE entity_role AS ENUM ('subject', 'origin', 'destination', 'reference_area');
CREATE TYPE nature AS ENUM ('original', 'derived');
CREATE TYPE derivation_kind AS ENUM ('internal', 'external');
CREATE TYPE derivation_method AS ENUM (
  'simple_sum',
  'area_weighting',
  'population_weighting',
  'interpolation',
  'mean_annual_growth_rate'
);

-- Lots et révisions (§5.10, §5.11).
CREATE TYPE batch_status AS ENUM ('proposed', 'validated', 'partially_validated', 'rejected');
CREATE TYPE operation AS ENUM ('create', 'correct', 'review_status_change');

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
