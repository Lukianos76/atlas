"""Dérivations, entrées et tables de passage sont immuables : une dérivation à refaire est
une nouvelle exécution (docs/schema.md, §5.9)."""

from typing import LiteralString

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, Db, refused


def internal_derivation(db: Db) -> int:
    return db.value(
        """
        INSERT INTO derivation (derivation_kind, method)
        VALUES ('internal', 'area_weighting')
        RETURNING id
        """
    )


def test_derivation_tables_cannot_be_updated(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    level = f.level(db)
    derivation = internal_derivation(db)
    origin, destination = f.entity(db), f.entity(db)
    source = f.observation(db, variable, origin)
    result = db.value(
        """
        INSERT INTO observation (
          variable_id, entity_id, entity_role, reference_start_kind, reference_start_earliest,
          reference_start_latest, reference_start_date_id, reference_end_kind,
          value, nature, geography_date, derivation_id, certainty
        ) VALUES (%s, %s, 'subject', 'dated', %s, %s, %s, 'ongoing',
          250, 'derived', %s, %s, 'established')
        RETURNING id
        """,
        (variable, destination, J2000, J2000, f.historical_date(db, J2000), J2000, derivation),
    )
    db.execute(
        """
        INSERT INTO derivation_input
          (variable_id, observation_id, input_variable_id, input_observation_id)
        VALUES (%s, %s, %s, %s)
        """,
        (variable, result, variable, source),
    )
    crosswalk = db.value(
        """
        INSERT INTO crosswalk (derivation_id, from_entity_id, to_entity_id, share)
        VALUES (%s, %s, %s, 0.25)
        RETURNING id
        """,
        (derivation, origin, destination),
    )
    transfer = f.assertion(db, "transfer", subject_event=f.dated_event(db))
    db.execute(
        """
        INSERT INTO transfer_assertion (
          id, from_entity_id, from_level_id, to_entity_id, to_level_id, territory
        ) VALUES (%s, %s, %s, %s, %s, 'partial')
        """,
        (transfer, origin, level, destination, level),
    )
    f.cite(db, transfer)
    db.execute(
        "INSERT INTO crosswalk_transfer (crosswalk_id, transfer_assertion_id) VALUES (%s, %s)",
        (crosswalk, transfer),
    )
    db.check_deferred()

    updates: list[tuple[LiteralString, tuple[int, ...]]] = [
        ("UPDATE derivation SET caveat = 'réécrit' WHERE id = %s", (derivation,)),
        (
            "UPDATE derivation_input SET input_observation_id = input_observation_id "
            "WHERE variable_id = %s AND observation_id = %s",
            (variable, result),
        ),
        ("UPDATE crosswalk SET share = 0.5 WHERE id = %s", (crosswalk,)),
        (
            "UPDATE crosswalk_transfer SET crosswalk_id = crosswalk_id WHERE crosswalk_id = %s",
            (crosswalk,),
        ),
    ]
    # Le rôle d'import n'a pas le droit UPDATE ; le trigger arrête aussi le propriétaire.
    db.role(None)
    for query, params in updates:
        with refused(db, errors.RestrictViolation, "immutable_row"):
            db.execute(query, params)


def test_new_execution_is_a_new_derivation(db: Db) -> None:
    """Cas valide : refaire un calcul, c'est enregistrer une nouvelle exécution."""
    db.role(AGENT)
    first, second = internal_derivation(db), internal_derivation(db)
    assert first != second
    contributor = db.value(
        """
        SELECT c.db_role::text FROM derivation AS d JOIN contributor AS c ON c.id = d.contributor_id
        WHERE d.id = %s
        """,
        (second,),
    )
    assert contributor == AGENT
