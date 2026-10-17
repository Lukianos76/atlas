"""Contraintes propres aux observations (docs/schema.md, §5.8, D3, A7)."""

from typing import Any

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, Db, refused


def test_batch_and_locator_go_together(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    with refused(db, errors.CheckViolation, "observation_batch_locator"):
        f.observation(db, variable, f.entity(db), batch=batch, locator=None)
    with refused(db, errors.CheckViolation, "observation_locator_not_empty"):
        f.observation(db, variable, f.entity(db), batch=batch, locator="")
    f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")


def test_subject_is_the_only_entity_role(db: Db) -> None:
    """Rôles d'entité multiples reportés (A7)."""
    variable = f.variable(db)
    db.role(AGENT)
    observation_id = f.observation(db, variable, f.entity(db))
    with refused(db, errors.CheckViolation, "observation_entity_role_subject"):
        db.execute(
            "UPDATE observation SET entity_role = 'origin' WHERE variable_id = %s AND id = %s",
            (variable, observation_id),
        )


def derivation(db: Db, kind: str) -> int:
    values: dict[str, Any] = {"kind": kind, "author": None, "method": None, "citation": None}
    if kind == "internal":
        values["method"] = "mean_annual_growth_rate"
    else:
        values["author"] = f.entity(db)
        values["citation"] = f.citation(db)
    return db.value(
        """
        INSERT INTO derivation (derivation_kind, author_entity_id, method, method_citation_id)
        VALUES (%(kind)s, %(author)s, %(method)s, %(citation)s)
        RETURNING id
        """,
        values,
    )


def derived(db: Db, variable: int, derivation_id: int | None, geography: int | None) -> int:
    return db.value(
        """
        INSERT INTO observation (
          variable_id, entity_id, entity_role, reference_start_kind, reference_start_earliest,
          reference_start_latest, reference_start_date_id, reference_end_kind,
          value, nature, geography_date, derivation_id, certainty
        ) VALUES (%s, %s, 'subject', 'dated', %s, %s, %s, 'ongoing',
          1.5, 'derived', %s, %s, 'established')
        RETURNING id
        """,
        (
            variable,
            f.entity(db),
            J2000,
            J2000,
            f.historical_date(db, J2000),
            geography,
            derivation_id,
        ),
    )


def test_derived_observation_needs_derivation_and_geography_date(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    internal = derivation(db, "internal")
    with refused(db, errors.CheckViolation, "observation_derived_derivation"):
        derived(db, variable, None, J2000)
    with refused(db, errors.CheckViolation, "observation_derived_geography_date"):
        derived(db, variable, internal, None)


def test_internal_derivation_is_cited_through_its_inputs(db: Db) -> None:
    """Une dérivée interne est citée par transitivité, à travers ses entrées (ADR 0003)."""
    variable = f.variable(db)
    db.role(AGENT)
    internal = derivation(db, "internal")
    with refused(db, errors.CheckViolation, "observation_requires_source"):
        derived(db, variable, internal, J2000)
        db.check_deferred()

    source = f.observation(db, variable, f.entity(db))
    result = derived(db, variable, internal, J2000)
    db.execute(
        """
        INSERT INTO derivation_input
          (variable_id, observation_id, input_variable_id, input_observation_id)
        VALUES (%s, %s, %s, %s)
        """,
        (variable, result, variable, source),
    )
    db.check_deferred()


def test_external_derivation_cites_its_method(db: Db) -> None:
    db.role(AGENT)
    with refused(db, errors.CheckViolation, "derivation_external_citation"):
        db.execute(
            """
            INSERT INTO derivation (derivation_kind, author_entity_id)
            VALUES ('external', %s)
            """,
            (f.entity(db),),
        )
    derivation(db, "external")
