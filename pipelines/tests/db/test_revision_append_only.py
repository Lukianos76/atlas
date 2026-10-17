"""`revision` est en ajout seul et n'est écrite que par les triggers (docs/schema.md, §5.11)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, Db, refused

INSERT_REVISION = """
INSERT INTO revision (recorded_at, contributor_id, operation, review_status, assertion_id, snapshot)
SELECT now(), c.id, 'review_status_change', 'validated', %s, '{}'
FROM contributor AS c WHERE c.db_role = %s
"""


def test_direct_insert_is_refused(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.check_deferred()
    with refused(db, errors.InsufficientPrivilege, "revision_trigger_only"):
        db.execute(INSERT_REVISION, (assertion_id, AGENT))
    db.role(None)
    with refused(db, errors.InsufficientPrivilege, "revision_trigger_only"):
        db.execute(INSERT_REVISION, (assertion_id, AGENT))


def test_revision_cannot_be_updated_or_deleted(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.check_deferred()
    db.role(None)
    with refused(db, errors.RestrictViolation, "immutable_row"):
        db.execute(
            "UPDATE revision SET reason = 'réécrit' WHERE assertion_id = %s", (assertion_id,)
        )
    with refused(db, errors.RestrictViolation, "no_delete"):
        db.execute("DELETE FROM revision WHERE assertion_id = %s", (assertion_id,))


def test_trigger_writes_the_revision_with_connection_contributor(db: Db) -> None:
    """Cas valide : la révision de création, écrite au commit, porte le contributeur
    retrouvé par `current_user`."""
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.check_deferred()
    operation, contributor = db.conn.execute(
        """
        SELECT r.operation::text, c.db_role::text
        FROM revision AS r JOIN contributor AS c ON c.id = r.contributor_id
        WHERE r.assertion_id = %s
        """,
        (assertion_id,),
    ).fetchone() or (None, None)
    assert operation == "create"
    assert contributor == AGENT


def test_role_without_contributor_cannot_write(db: Db) -> None:
    """Le superutilisateur n'a pas de contributeur : l'assertion ne peut être révisée."""
    subject = f.entity(db)
    with refused(db, errors.InsufficientPrivilege, "contributor_required"):
        f.name(db, subject)
        db.check_deferred()
