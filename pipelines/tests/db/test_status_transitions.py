"""Transitions de statut et garde des rôles (docs/schema.md, §5.13 ; modèle §10.1, v3.2)."""

import pytest
from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, REVIEWER, Db, refused

SET_STATUS = "UPDATE assertion SET review_status = %s WHERE id = %s"


def assertion_in(db: Db, status: str) -> int:
    """Assertion amenée au statut voulu par les transitions admises."""
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.context("reason", "motif d'essai")
    path = {
        "proposed": [],
        "validated": [(REVIEWER, "validated")],
        "contested": [(REVIEWER, "validated"), (AGENT, "contested")],
        "withdrawn": [(REVIEWER, "withdrawn")],
    }[status]
    for role, step in path:
        db.role(role)
        db.execute(SET_STATUS, (step, assertion_id))
    return assertion_id


@pytest.mark.parametrize(
    ("start", "role", "target"),
    [
        ("validated", AGENT, "contested"),
        ("withdrawn", AGENT, "proposed"),
        ("proposed", REVIEWER, "validated"),
        ("contested", REVIEWER, "validated"),
        ("proposed", REVIEWER, "withdrawn"),
        ("contested", REVIEWER, "withdrawn"),
    ],
)
def test_allowed_transitions(db: Db, start: str, role: str, target: str) -> None:
    assertion_id = assertion_in(db, start)
    db.role(role)
    db.execute(SET_STATUS, (target, assertion_id))
    db.check_deferred()


@pytest.mark.parametrize(
    ("start", "target"),
    [
        ("proposed", "validated"),
        ("contested", "validated"),
        ("proposed", "withdrawn"),
        ("contested", "withdrawn"),
    ],
)
def test_decisions_are_reserved_to_review_role(db: Db, start: str, target: str) -> None:
    assertion_id = assertion_in(db, start)
    db.role(AGENT)
    with refused(db, errors.InsufficientPrivilege, "review_status_guard"):
        db.execute(SET_STATUS, (target, assertion_id))


@pytest.mark.parametrize(
    ("start", "target"),
    [
        ("proposed", "contested"),  # une proposition se rejette, elle ne se conteste pas
        ("contested", "proposed"),  # une contestation se règle par validated ou withdrawn
        ("validated", "proposed"),  # sans correction de contenu
        ("withdrawn", "validated"),
    ],
)
@pytest.mark.parametrize("role", [AGENT, REVIEWER])
def test_forbidden_transitions(db: Db, start: str, target: str, role: str) -> None:
    assertion_id = assertion_in(db, start)
    db.role(role)
    with refused(db, errors.CheckViolation, "review_status_transition"):
        db.execute(SET_STATUS, (target, assertion_id))


@pytest.mark.parametrize("role", [AGENT, REVIEWER])
def test_creation_is_always_proposed(db: Db, role: str) -> None:
    db.role(role)
    subject = f.entity(db)
    with refused(db, errors.CheckViolation, "review_status_transition"):
        db.execute(
            """
            INSERT INTO assertion (
              assertion_type, subject_entity_id, start_kind, start_earliest, start_latest,
              start_date_id, end_kind, certainty, review_status
            )
            SELECT 'name', %s, 'dated', earliest, latest, id, 'ongoing', 'established',
              'validated'
            FROM historical_date WHERE id = %s
            """,
            (subject, f.historical_date(db, J2000)),
        )


def test_content_correction_sends_validated_assertion_back_to_review(db: Db) -> None:
    """Modèle §10.1 v3.2 : `validated` → `proposed` par une correction, par tout rôle."""
    assertion_id = assertion_in(db, "validated")
    db.role(AGENT)
    db.execute("UPDATE name_assertion SET text = 'nom corrigé' WHERE id = %s", (assertion_id,))
    status = db.value("SELECT review_status::text FROM assertion WHERE id = %s", (assertion_id,))
    assert status == "proposed"


def test_trunk_correction_sends_validated_assertion_back_to_review(db: Db) -> None:
    assertion_id = assertion_in(db, "validated")
    db.role(AGENT)
    db.execute("UPDATE assertion SET certainty = 'probable' WHERE id = %s", (assertion_id,))
    status = db.value("SELECT review_status::text FROM assertion WHERE id = %s", (assertion_id,))
    assert status == "proposed"


def test_correction_keeps_other_statuses(db: Db) -> None:
    assertion_id = assertion_in(db, "contested")
    db.role(AGENT)
    db.execute("UPDATE name_assertion SET text = 'nom corrigé' WHERE id = %s", (assertion_id,))
    status = db.value("SELECT review_status::text FROM assertion WHERE id = %s", (assertion_id,))
    assert status == "contested"
