"""Fabriques de données d'essai pour les tests des invariants du schéma.

Toutes les valeurs sont fictives (codes, titres, localisateurs générés) : ce ne sont pas
des données de l'atlas, et aucune ne dépend des identifiants attribués par la base
(docs/schema.md, §4). Sauf mention contraire, une fabrique écrit avec le rôle courant
de la connexion ; les référentiels, que les rôles de groupe n'écrivent pas, sont créés
par le superutilisateur.
"""

from tests.db.support import J2000, Db, unique

# Polygone d'essai (un carré d'un dixième de degré), en WGS 84.
SQUARE = "SRID=4326;POLYGON((7 48,7.1 48,7.1 48.1,7 48.1,7 48))"


def historical_date(db: Db, day: int) -> int:
    return db.value(
        """
        INSERT INTO historical_date
          (original_expression, source_calendar, granularity, qualifier, earliest, latest)
        VALUES (%s, 'gregorian', 'day', 'exact', %s, %s)
        RETURNING id
        """,
        (f"jour julien {day}", day, day),
    )


def citation(db: Db) -> int:
    work = db.value(
        """
        INSERT INTO source_work (source_type, title, license, language)
        VALUES ('primary', %s, 'CC0-1.0', 'fr')
        RETURNING id
        """,
        (unique("œuvre d'essai"),),
    )
    return db.value(
        "INSERT INTO citation (source_work_id, locator) VALUES (%s, %s) RETURNING id",
        (work, unique("page")),
    )


def entity(db: Db) -> int:
    return db.value(
        """
        INSERT INTO entity (entity_category_id)
        SELECT id FROM entity_category WHERE code = 'administrative'
        RETURNING id
        """
    )


def event(db: Db) -> int:
    return db.value("INSERT INTO event DEFAULT VALUES RETURNING id")


def registry(db: Db) -> int:
    with db.as_role(None):
        return db.value(
            "INSERT INTO registry (code) VALUES (%s) RETURNING id", (unique("référentiel"),)
        )


def division_system(db: Db) -> int:
    authority = entity(db)
    with db.as_role(None):
        return db.value(
            "INSERT INTO division_system (authority_entity_id, label) VALUES (%s, %s) RETURNING id",
            (authority, unique("système")),
        )


def level(db: Db) -> int:
    system = division_system(db)
    with db.as_role(None):
        return db.value(
            "INSERT INTO level (division_system_id, label, rank) VALUES (%s, %s, 1) RETURNING id",
            (system, unique("niveau")),
        )


def variable(db: Db) -> int:
    with db.as_role(None):
        return db.value(
            """
            INSERT INTO variable (label, definition, unit, value_type, aggregation_rule)
            VALUES (%s, 'variable d''essai', 'habitants', 'quantity', 'additive')
            RETURNING id
            """,
            (unique("variable"),),
        )


def assertion(
    db: Db,
    assertion_type: str,
    *,
    subject_entity: int | None = None,
    subject_event: int | None = None,
    subject_system: int | None = None,
    start: int = J2000,
    end: int | None = None,
    authority: int | None = None,
) -> int:
    """Tronc d'une assertion : période datée `[start, end[` (fin `ongoing` sans `end`),
    sauf pour un sujet événement, qui n'a pas de période (N1)."""
    if subject_event is not None:
        return db.value(
            """
            INSERT INTO assertion (assertion_type, subject_event_id, certainty, authority_entity_id)
            VALUES (%s, %s, 'established', %s)
            RETURNING id
            """,
            (assertion_type, subject_event, authority),
        )
    return db.value(
        """
        INSERT INTO assertion (
          assertion_type, subject_entity_id, subject_division_system_id,
          start_kind, start_earliest, start_latest, start_date_id,
          end_kind, end_earliest, end_latest, end_date_id,
          certainty, authority_entity_id
        ) VALUES (
          %(type)s, %(entity)s, %(system)s,
          'dated', %(start)s, %(start)s, %(start_id)s,
          %(end_kind)s, %(end)s, %(end)s, %(end_id)s,
          'established', %(authority)s
        )
        RETURNING id
        """,
        {
            "type": assertion_type,
            "entity": subject_entity,
            "system": subject_system,
            "start": start,
            "start_id": historical_date(db, start),
            "end_kind": "ongoing" if end is None else "dated",
            "end": end,
            "end_id": None if end is None else historical_date(db, end),
            "authority": authority,
        },
    )


def cite(db: Db, assertion_id: int, citation_id: int | None = None, role: str = "value") -> int:
    """Lie une citation (nouvelle par défaut) à l'assertion ; renvoie la citation."""
    if citation_id is None:
        citation_id = citation(db)
    db.execute(
        """
        INSERT INTO assertion_citation (assertion_id, citation_id, citation_role)
        VALUES (%s, %s, %s)
        """,
        (assertion_id, citation_id, role),
    )
    return citation_id


def name(
    db: Db,
    subject: int,
    *,
    name_type: str = "common",
    authority: int | None = None,
    with_citation: bool = True,
) -> int:
    assertion_id = assertion(db, "name", subject_entity=subject, authority=authority)
    db.execute(
        """
        INSERT INTO name_assertion (id, text, language, script, name_type)
        VALUES (%s, %s, 'fr', 'Latn', %s)
        """,
        (assertion_id, unique("nom"), name_type),
    )
    if with_citation:
        cite(db, assertion_id)
    return assertion_id


def external_id(
    db: Db,
    subject: int,
    registry_id: int,
    code: str,
    *,
    object_type: str | None = "COM",
    start: int = J2000,
    end: int | None = None,
) -> int:
    assertion_id = assertion(db, "external_id", subject_entity=subject, start=start, end=end)
    db.execute(
        """
        INSERT INTO external_id_assertion (id, registry_id, object_type, code)
        VALUES (%s, %s, %s, %s)
        """,
        (assertion_id, registry_id, object_type, code),
    )
    cite(db, assertion_id)
    return assertion_id


def geometry(db: Db, subject: int) -> int:
    assertion_id = assertion(db, "geometry", subject_entity=subject)
    db.execute(
        """
        INSERT INTO geometry_assertion (id, shape, method, source_crs)
        VALUES (%s, %s, 'official_survey', 'EPSG:2154')
        """,
        (assertion_id, SQUARE),
    )
    cite(db, assertion_id, role="geometry")
    return assertion_id


def dated_event(db: Db, day: int = J2000) -> int:
    """Événement avec sa date d'effet, citée (A4)."""
    event_id = event(db)
    date_assertion = assertion(db, "event_date", subject_event=event_id)
    db.execute(
        """
        INSERT INTO event_date_assertion (id, event_date_kind, date_id)
        VALUES (%s, 'effective', %s)
        """,
        (date_assertion, historical_date(db, day)),
    )
    cite(db, date_assertion, role="date")
    return event_id


def import_batch(db: Db, citation_id: int | None = None) -> int:
    """Lot au statut `proposed` ; le responsable est le contributeur du rôle courant."""
    return db.value(
        """
        INSERT INTO import_batch (citation_id, procedure, scope)
        VALUES (%s, 'procédure d''essai', '{"essai": true}')
        RETURNING id
        """,
        (citation(db) if citation_id is None else citation_id,),
    )


def observation(
    db: Db,
    variable_id: int,
    subject: int,
    *,
    batch: int | None = None,
    locator: str | None = None,
    with_citation: bool = True,
) -> int:
    """Observation originale ; hors lot, elle reçoit une citation sauf `with_citation=False`."""
    observation_id = db.value(
        """
        INSERT INTO observation (
          variable_id, entity_id, entity_role,
          reference_start_kind, reference_start_earliest, reference_start_latest,
          reference_start_date_id, reference_end_kind, reference_end_earliest,
          reference_end_latest, reference_end_date_id,
          value, nature, certainty, import_batch_id, locator
        ) VALUES (
          %(variable)s, %(entity)s, 'subject',
          'dated', %(day)s, %(day)s, %(date)s, 'dated', %(next)s, %(next)s, %(next_date)s,
          1000, 'original', 'established', %(batch)s, %(locator)s
        )
        RETURNING id
        """,
        {
            "variable": variable_id,
            "entity": subject,
            "day": J2000,
            "date": historical_date(db, J2000),
            "next": J2000 + 1,
            "next_date": historical_date(db, J2000 + 1),
            "batch": batch,
            "locator": locator,
        },
    )
    if batch is None and with_citation:
        db.execute(
            """
            INSERT INTO observation_citation
              (variable_id, observation_id, citation_id, citation_role)
            VALUES (%s, %s, %s, 'value')
            """,
            (variable_id, observation_id, citation(db)),
        )
    return observation_id


def revisions(db: Db, assertion_id: int) -> list[tuple[str, str]]:
    """(opération, statut) des révisions d'une assertion, dans l'ordre."""
    rows = db.conn.execute(
        """
        SELECT operation::text, review_status::text FROM revision
        WHERE assertion_id = %s ORDER BY recorded_at, id
        """,
        (assertion_id,),
    ).fetchall()
    return [(row[0], row[1]) for row in rows]
