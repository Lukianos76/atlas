"""Appartenance à un lot : on n'ajoute qu'à son propre lot encore ouvert, et le lot
d'une observation est figé (docs/schema.md, §5.10, E13).

Sans ces gardes, un rôle d'import pourrait verser des observations dans un lot déjà
validé, qui seraient validées sans relecture, ou rattacher ses données au lot d'un
autre contributeur.
"""

import pytest
from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, REVIEWER, Db, refused, unique

STATUS = "SELECT observation_review_status(%s, %s)::text"


def decided_batch(db: Db, decision: str) -> int:
    """Lot de l'agent, décidé par le vérificateur ; le rôle courant redevient l'agent."""
    db.role(AGENT)
    batch = f.import_batch(db)
    db.role(REVIEWER)
    db.context("reason", "décision d'essai")
    db.execute(
        "UPDATE import_batch SET validation_report = '{}', batch_status = %s WHERE id = %s",
        (decision, batch),
    )
    db.role(AGENT)
    return batch


def other_contributor_batch(db: Db) -> int:
    """Lot ouvert dont le responsable est le vérificateur ; le rôle courant devient l'agent."""
    db.role(REVIEWER)
    batch = f.import_batch(db)
    db.role(AGENT)
    return batch


@pytest.mark.parametrize("decision", ["validated", "partially_validated", "rejected"])
def test_observation_cannot_join_a_decided_batch(db: Db, decision: str) -> None:
    variable = f.variable(db)
    batch = decided_batch(db, decision)
    with refused(db, errors.InsufficientPrivilege, "observation_batch_owner"):
        f.observation(db, variable, f.entity(db), batch=batch, locator=unique("cellule"))


def test_observation_cannot_join_another_contributor_batch(db: Db) -> None:
    variable = f.variable(db)
    batch = other_contributor_batch(db)
    with refused(db, errors.InsufficientPrivilege, "observation_batch_owner"):
        f.observation(db, variable, f.entity(db), batch=batch, locator=unique("cellule"))


def test_observation_joins_its_own_open_batch(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    observation = f.observation(db, variable, f.entity(db), batch=batch, locator=unique("cellule"))
    assert db.value(STATUS, (variable, observation)) == "proposed"


def test_observation_batch_is_frozen(db: Db) -> None:
    """Une observation hors lot ne rejoint pas un lot après coup, ni l'inverse."""
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    loose = f.observation(db, variable, f.entity(db))
    # Contrôles différés laissés au commit : seul le gel, immédiat, est éprouvé ici.
    db.context("reason", "rattachement d'essai")
    with refused(db, errors.RestrictViolation, "observation_batch_frozen"):
        db.execute(
            """
            UPDATE observation SET import_batch_id = %s, locator = %s
            WHERE variable_id = %s AND id = %s
            """,
            (batch, unique("cellule"), variable, loose),
        )
    member = f.observation(db, variable, f.entity(db), batch=batch, locator=unique("cellule"))
    with refused(db, errors.RestrictViolation, "observation_batch_frozen"):
        db.execute(
            """
            UPDATE observation SET import_batch_id = NULL, locator = NULL
            WHERE variable_id = %s AND id = %s
            """,
            (variable, member),
        )


@pytest.mark.parametrize("decision", ["validated", "partially_validated", "rejected"])
def test_assertion_cannot_join_a_decided_batch(db: Db, decision: str) -> None:
    batch = decided_batch(db, decision)
    db.context("import_batch_id", str(batch))
    with refused(db, errors.InsufficientPrivilege, "assertion_batch_owner"):
        f.name(db, f.entity(db))
        db.check_deferred()


def test_assertion_cannot_join_another_contributor_batch(db: Db) -> None:
    batch = other_contributor_batch(db)
    db.context("import_batch_id", str(batch))
    with refused(db, errors.InsufficientPrivilege, "assertion_batch_owner"):
        f.name(db, f.entity(db))
        db.check_deferred()


def test_assertion_joins_its_own_open_batch(db: Db) -> None:
    """La propagation de la validation au lot, sous le rôle du vérificateur, n'est pas une
    nouvelle appartenance : elle reste admise (test_batch_validation_role.py)."""
    db.role(AGENT)
    batch = f.import_batch(db)
    db.context("import_batch_id", str(batch))
    assertion_id = f.name(db, f.entity(db))
    db.check_deferred()
    assert (
        db.value(
            "SELECT import_batch_id FROM revision WHERE assertion_id = %s AND operation = 'create'",
            (assertion_id,),
        )
        == batch
    )
