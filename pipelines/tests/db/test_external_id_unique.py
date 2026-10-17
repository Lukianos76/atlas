"""Un code d'un référentiel ne désigne qu'une entité à une date (docs/schema.md, §5.4, A11, N11).

Codes fictifs, générés : ce ne sont pas des codes du COG.
"""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, REVIEWER, Db, refused, unique


def test_same_code_for_two_entities_at_same_date_is_refused(db: Db) -> None:
    registry = f.registry(db)
    db.role(AGENT)
    code = unique("C")
    f.external_id(db, f.entity(db), registry, code, start=J2000)
    with refused(db, errors.ExclusionViolation, "external_id_assertion_code_unique"):
        f.external_id(db, f.entity(db), registry, code, start=J2000 + 100)


def test_same_code_for_two_entities_at_disjoint_dates_is_accepted(db: Db) -> None:
    registry = f.registry(db)
    db.role(AGENT)
    code = unique("C")
    f.external_id(db, f.entity(db), registry, code, start=J2000, end=J2000 + 100)
    f.external_id(db, f.entity(db), registry, code, start=J2000 + 100)
    db.check_deferred()


def test_same_code_with_other_object_type_is_accepted(db: Db) -> None:
    """Le cas d'Annecy (modèle §11.2) : même code en `COM` et en `COMD`."""
    registry = f.registry(db)
    db.role(AGENT)
    code = unique("C")
    f.external_id(db, f.entity(db), registry, code, object_type="COM")
    f.external_id(db, f.entity(db), registry, code, object_type="COMD")
    db.check_deferred()


def test_same_code_for_same_entity_is_accepted(db: Db) -> None:
    registry = f.registry(db)
    db.role(AGENT)
    subject = f.entity(db)
    code = unique("C")
    f.external_id(db, subject, registry, code)
    f.external_id(db, subject, registry, code, start=J2000 + 10)
    db.check_deferred()


def test_withdrawn_code_frees_the_triplet(db: Db) -> None:
    """Seul un code retiré libère le triplet (N11) ; le statut est recopié par la clé."""
    registry = f.registry(db)
    db.role(AGENT)
    code = unique("C")
    first = f.external_id(db, f.entity(db), registry, code)
    db.role(REVIEWER)
    db.context("reason", "code attribué par erreur")
    db.execute("UPDATE assertion SET review_status = 'withdrawn' WHERE id = %s", (first,))
    db.role(AGENT)
    f.external_id(db, f.entity(db), registry, code)
    db.check_deferred()
