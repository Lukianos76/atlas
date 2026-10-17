-- Œuvres sources et citations (docs/schema.md, §5.2).

-- migrate:up

SET ROLE atlas_owner;

CREATE TABLE source_work (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_type source_type NOT NULL,
  title text NOT NULL,
  authors text[],
  publisher text,
  publication_date_id bigint REFERENCES historical_date,
  version text,
  edition text,
  vintage text,
  persistent_ids jsonb,
  license text NOT NULL,
  license_archived_copy text,
  language text NOT NULL,
  parent_work_id integer REFERENCES source_work
);

-- Immuable et partageable entre assertions (A9) ; le rôle est porté par les liens.
CREATE TABLE citation (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_work_id integer NOT NULL REFERENCES source_work,
  locator text NOT NULL CONSTRAINT citation_locator_not_empty CHECK (locator <> ''),
  accessed_url text,
  archived_copy text,
  accessed_on date,
  excerpt text
);

CREATE INDEX ON citation (source_work_id);

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
