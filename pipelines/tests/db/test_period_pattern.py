"""Motif de période : nature des bornes et accord avec les dates historiques
(docs/schema.md, §3, ADR 0003)."""

from typing import Any

import pytest
from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, Db, refused

INSERT = """
INSERT INTO assertion (
  assertion_type, subject_entity_id,
  start_kind, start_earliest, start_latest, start_date_id,
  end_kind, end_earliest, end_latest, end_date_id, certainty
) VALUES (
  'name', %(entity)s,
  %(start_kind)s, %(start_earliest)s, %(start_latest)s, %(start_date)s,
  %(end_kind)s, %(end_earliest)s, %(end_latest)s, %(end_date)s, 'established'
)
RETURNING id
"""


def period(db: Db, **overrides: Any) -> dict[str, Any]:
    """Période valide `[J2000, J2000 + 10[`, à laquelle on applique des écarts."""
    values: dict[str, Any] = {
        "entity": f.entity(db),
        "start_kind": "dated",
        "start_earliest": J2000,
        "start_latest": J2000,
        "start_date": f.historical_date(db, J2000),
        "end_kind": "dated",
        "end_earliest": J2000 + 10,
        "end_latest": J2000 + 10,
        "end_date": f.historical_date(db, J2000 + 10),
    }
    values.update(overrides)
    return values


@pytest.mark.parametrize(
    ("overrides", "constraint"),
    [
        ({"start_earliest": None}, "assertion_start_dated"),
        ({"start_kind": "unknown"}, "assertion_start_unknown"),
        ({"end_kind": "ongoing"}, "assertion_end_ongoing"),
        ({"end_latest": None}, "assertion_end_dated"),
        ({"end_kind": "unknown", "end_earliest": None}, "assertion_end_unknown"),
        ({"start_kind": None}, "assertion_period_iff_not_event"),
    ],
)
def test_bounds_inconsistent_with_kind_are_refused(
    db: Db, overrides: dict[str, Any], constraint: str
) -> None:
    db.role(AGENT)
    values = period(db, **overrides)
    with refused(db, errors.CheckViolation, constraint):
        db.execute(INSERT, values)


def test_bounds_disagreeing_with_historical_date_are_refused(db: Db) -> None:
    db.role(AGENT)
    values = period(db, end_earliest=J2000 + 9, end_latest=J2000 + 9)
    with refused(db, errors.ForeignKeyViolation, "assertion_end_earliest_fkey"):
        db.execute(INSERT, values)


def test_valid_periods_are_accepted(db: Db) -> None:
    db.role(AGENT)
    dated = db.value(INSERT, period(db))
    ongoing = db.value(
        INSERT, period(db, end_kind="ongoing", end_earliest=None, end_latest=None, end_date=None)
    )
    # Fin inconnue : dernière attestation seule (N2).
    unknown = db.value(INSERT, period(db, end_kind="unknown", end_latest=None))
    cores = [
        db.value("SELECT core_range::text FROM assertion WHERE id = %s", (assertion_id,))
        for assertion_id in (dated, ongoing, unknown)
    ]
    assert cores == [f"[{J2000},{J2000 + 10})", f"[{J2000},)", f"[{J2000},{J2000 + 10})"]


def test_crossed_bounds_give_an_empty_core(db: Db) -> None:
    """Début au plus tard après la fin au plus tôt : noyau vide, sans erreur (§3.1)."""
    db.role(AGENT)
    fuzzy_start = db.value(
        """
        INSERT INTO historical_date
          (original_expression, source_calendar, granularity, qualifier, earliest, latest)
        VALUES ('date floue d''essai', 'gregorian', 'month', 'approximate', %s, %s)
        RETURNING id
        """,
        (J2000, J2000 + 20),
    )
    created = db.value(INSERT, period(db, start_latest=J2000 + 20, start_date=fuzzy_start))
    assert db.value("SELECT isempty(core_range) FROM assertion WHERE id = %s", (created,))
