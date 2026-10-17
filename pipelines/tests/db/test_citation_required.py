"""P3 : aucune assertion ni observation hors lot sans source (docs/schema.md, §5.3, §5.8, D3)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, Db, refused


def test_assertion_without_citation_is_refused_at_commit(db: Db) -> None:
    db.role(AGENT)
    subject = f.entity(db)
    with refused(db, errors.CheckViolation, "assertion_requires_citation"):
        f.name(db, subject, with_citation=False)
        db.check_deferred()


def test_assertion_with_citation_is_accepted(db: Db) -> None:
    db.role(AGENT)
    f.name(db, f.entity(db))
    db.check_deferred()


def test_observation_outside_batch_without_source_is_refused(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    subject = f.entity(db)
    with refused(db, errors.CheckViolation, "observation_requires_source"):
        f.observation(db, variable, subject, with_citation=False)
        db.check_deferred()


def test_observation_outside_batch_with_citation_is_accepted(db: Db) -> None:
    variable = f.variable(db)
    db.role(AGENT)
    f.observation(db, variable, f.entity(db))
    db.check_deferred()


def test_observation_in_batch_is_cited_by_batch_and_locator(db: Db) -> None:
    """Une observation de lot n'a pas de citation propre : le lot et la cellule la citent."""
    variable = f.variable(db)
    db.role(AGENT)
    batch = f.import_batch(db)
    f.observation(db, variable, f.entity(db), batch=batch, locator="row=2;column=P20")
    db.check_deferred()
