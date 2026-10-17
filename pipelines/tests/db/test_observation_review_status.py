"""Statut d'une observation : fonction `set_observation_review_status` et garde des rôles
(docs/schema.md, §5.11, §5.12, §5.13, E5, N4)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, REVIEWER, Db, refused

SET = "SELECT set_observation_review_status(%s, %s, %s, %s)"
STATUS = "SELECT observation_review_status(%s, %s)::text"


def test_status_changes_go_through_the_guard(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    observation = f.observation(db, variable, f.entity(db))
    db.check_deferred()
    assert db.value(STATUS, (variable, observation)) == "proposed"

    with refused(db, errors.InsufficientPrivilege, "review_status_guard"):
        db.execute(SET, (variable, observation, "withdrawn", "valeur erronée"))
    with refused(db, errors.CheckViolation, "review_status_transition"):
        db.execute(SET, (variable, observation, "contested", "valeur douteuse"))

    db.role(REVIEWER)
    db.execute(SET, (variable, observation, "validated", None))
    db.role(AGENT)
    db.execute(SET, (variable, observation, "contested", "autre source contradictoire"))
    db.role(REVIEWER)
    db.execute(SET, (variable, observation, "withdrawn", "contestation admise"))
    assert db.value(STATUS, (variable, observation)) == "withdrawn"


def test_withdrawal_requires_a_reason(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    observation = f.observation(db, variable, f.entity(db))
    db.check_deferred()
    db.role(REVIEWER)
    with refused(db, errors.CheckViolation, "revision_reason_required"):
        db.execute(SET, (variable, observation, "withdrawn", None))


def test_batch_observation_follows_its_batch(db: Db) -> None:
    """Sans révision propre, une observation de lot a le statut de son lot (N4)."""
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    kept = f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")
    dropped = f.observation(db, variable, f.entity(db), batch=batch, locator="row=3;column=P20")
    assert db.value(STATUS, (variable, kept)) == "proposed"

    # Les observations écartées sont retirées avant la décision, tant qu'elles sont
    # proposées : `validated` → `withdrawn` n'est pas une transition admise.
    db.role(REVIEWER)
    db.execute(SET, (variable, dropped, "withdrawn", "valeur hors périmètre"))
    db.context("reason", "une valeur écartée")
    db.execute(
        """
        UPDATE import_batch SET validation_report = '{}', batch_status = 'partially_validated'
        WHERE id = %s
        """,
        (batch,),
    )
    assert db.value(STATUS, (variable, kept)) == "validated"
    assert db.value(STATUS, (variable, dropped)) == "withdrawn"


def test_correction_sends_validated_observation_back_to_review(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    observation = f.observation(db, variable, f.entity(db))
    db.check_deferred()
    db.role(REVIEWER)
    db.execute(SET, (variable, observation, "validated", None))
    db.role(AGENT)
    db.context("reason", "valeur rectifiée par la source")
    db.execute(
        "UPDATE observation SET value = 1001 WHERE variable_id = %s AND id = %s",
        (variable, observation),
    )
    assert db.value(STATUS, (variable, observation)) == "proposed"
