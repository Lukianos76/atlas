"""Import rejouable : une cellule ne produit qu'une observation par lot (docs/schema.md, §5.8)."""

import pytest
from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, Db


def test_same_cell_twice_in_a_batch_is_refused(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")
    with pytest.raises(errors.UniqueViolation) as info, db.conn.transaction():
        f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")
    # La violation est signalée sur l'index de la partition : on vérifie la clé visée.
    assert "(variable_id, import_batch_id, locator)" in (info.value.diag.message_detail or "")


def test_other_cell_in_the_same_batch_is_accepted(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")
    f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P21")
    f.observation(db, variable, f.entity(db), batch=batch, locator="row=3;column=P20")
    db.check_deferred()


def test_same_cell_in_another_batch_is_accepted(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    for _ in range(2):
        batch = f.import_batch(db)
        f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")
    db.check_deferred()


def test_observations_outside_batches_are_not_concerned(db: Db) -> None:
    """Hors lot, lot et localisateur sont NULL : les NULL sont distincts."""
    variable = f.variable(db)
    db.role(AGENT)
    subject = f.entity(db)
    f.observation(db, variable, subject)
    f.observation(db, variable, subject)
    db.check_deferred()
