-- Assertions sur les événements (docs/schema.md, §5.5). La table nue `event` est créée
-- avec les référentiels (E1). Ces assertions n'ont pas de période de validité (N1).

-- migrate:up

SET ROLE atlas_owner;

-- Le type est une assertion, pour admettre plus tard des types concurrents (Q8).
CREATE TABLE event_type_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'event_type'
    CHECK (assertion_type = 'event_type'),
  event_type_id smallint NOT NULL REFERENCES event_type,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

-- La date est le contenu de l'assertion (N1). Bornes copiées de la date historique
-- par trigger, et garanties par les clés composites.
CREATE TABLE event_date_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'event_date'
    CHECK (assertion_type = 'event_date'),
  event_date_kind event_date_kind NOT NULL,
  date_id bigint NOT NULL,
  earliest int4 NOT NULL,
  latest int4 NOT NULL,
  end_date_id bigint,
  end_earliest int4,
  end_latest int4,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type),
  FOREIGN KEY (date_id, earliest, latest) REFERENCES historical_date (id, earliest, latest),
  FOREIGN KEY (end_date_id, end_earliest, end_latest)
    REFERENCES historical_date (id, earliest, latest),
  CONSTRAINT event_date_assertion_end_block CHECK (
    num_nonnulls(end_date_id, end_earliest, end_latest) IN (0, 3)
  )
);

CREATE INDEX ON event_date_assertion (latest);

CREATE TABLE participation_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'participation'
    CHECK (assertion_type = 'participation'),
  entity_id integer NOT NULL REFERENCES entity,
  role participation_role NOT NULL,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type)
);

CREATE INDEX ON participation_assertion (entity_id, role);

CREATE TABLE transfer_assertion (
  id bigint PRIMARY KEY,
  assertion_type assertion_type NOT NULL DEFAULT 'transfer' CHECK (assertion_type = 'transfer'),
  from_entity_id integer NOT NULL REFERENCES entity,
  from_level_id smallint NOT NULL REFERENCES level,
  to_entity_id integer NOT NULL REFERENCES entity,
  to_level_id smallint NOT NULL REFERENCES level,
  territory territory NOT NULL,
  share numeric CONSTRAINT transfer_assertion_share_range CHECK (share > 0 AND share <= 1),
  share_basis share_basis,
  FOREIGN KEY (id, assertion_type) REFERENCES assertion (id, assertion_type),
  CONSTRAINT transfer_assertion_share_basis CHECK ((share IS NULL) = (share_basis IS NULL)),
  -- La totalité vaut 1 : on ne la stocke pas.
  CONSTRAINT transfer_assertion_share_partial CHECK (territory = 'partial' OR share IS NULL)
);

CREATE INDEX ON transfer_assertion (from_entity_id);
CREATE INDEX ON transfer_assertion (to_entity_id);

RESET ROLE;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
