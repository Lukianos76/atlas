"""Gel d'un lot : procédure et périmètre dès la création, rapport à la décision
(docs/schema.md, §5.10)."""

from typing import LiteralString

import pytest
from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, REVIEWER, Db, refused

REPORT = "UPDATE import_batch SET validation_report = %s WHERE id = %s"


@pytest.mark.parametrize(
    "assignment",
    ["procedure = 'autre procédure'", "scope = '{\"autre\": true}'"],
)
def test_procedure_and_scope_are_frozen_at_creation(db: Db, assignment: LiteralString) -> None:
    db.role(AGENT)
    batch = f.import_batch(db)
    with refused(db, errors.RestrictViolation, "batch_frozen"):
        db.execute(f"UPDATE import_batch SET {assignment} WHERE id = %s", (batch,))


def test_report_is_written_while_proposed(db: Db) -> None:
    db.role(AGENT)
    batch = f.import_batch(db)
    db.execute(REPORT, ('{"contrôles": "en cours"}', batch))
    db.execute(REPORT, ('{"contrôles": "ok"}', batch))


@pytest.mark.parametrize("decision", ["validated", "partially_validated", "rejected"])
def test_report_is_frozen_after_decision(db: Db, decision: str) -> None:
    db.role(AGENT)
    batch = f.import_batch(db)
    db.execute(REPORT, ('{"contrôles": "ok"}', batch))
    db.role(REVIEWER)
    db.context("reason", "décision d'essai")
    db.execute("UPDATE import_batch SET batch_status = %s WHERE id = %s", (decision, batch))
    for role in (AGENT, REVIEWER):
        db.role(role)
        with refused(db, errors.RestrictViolation, "batch_frozen"):
            db.execute(REPORT, ('{"contrôles": "réécrits"}', batch))


def test_decision_is_final(db: Db) -> None:
    db.role(AGENT)
    batch = f.import_batch(db)
    db.execute(REPORT, ('{"contrôles": "ok"}', batch))
    db.role(REVIEWER)
    db.context("reason", "décision d'essai")
    db.execute("UPDATE import_batch SET batch_status = 'rejected' WHERE id = %s", (batch,))
    with refused(db, errors.CheckViolation, "batch_status_transition"):
        db.execute("UPDATE import_batch SET batch_status = 'validated' WHERE id = %s", (batch,))
