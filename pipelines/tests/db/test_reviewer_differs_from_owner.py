"""Le vérificateur d'un lot n'en est pas le responsable (docs/schema.md, §5.10, A13)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, REVIEWER, Db, refused

DECIDE = "UPDATE import_batch SET validation_report = '{}', batch_status = %s WHERE id = %s"


def test_reviewer_cannot_decide_own_batch(db: Db) -> None:
    db.role(REVIEWER)
    batch = f.import_batch(db)
    with refused(db, errors.CheckViolation, "import_batch_reviewer_not_owner"):
        db.execute(DECIDE, ("validated", batch))


def test_reviewer_decides_batch_of_another_contributor(db: Db) -> None:
    db.role(AGENT)
    batch = f.import_batch(db)
    db.role(REVIEWER)
    db.context("reason", "échantillon non conforme")
    db.execute(DECIDE, ("rejected", batch))
    owner_is_agent, reviewer_is_reviewer = db.conn.execute(
        """
        SELECT
          b.owner_id = (SELECT id FROM contributor WHERE db_role = %s),
          b.reviewer_id = (SELECT id FROM contributor WHERE db_role = %s)
        FROM import_batch AS b WHERE b.id = %s
        """,
        (AGENT, REVIEWER, batch),
    ).fetchone() or (None, None)
    assert owner_is_agent is True
    assert reviewer_is_reviewer is True


def test_owner_is_never_declared(db: Db) -> None:
    """Le responsable déclaré est remplacé par le contributeur de la connexion (E4)."""
    db.role(AGENT)
    citation = f.citation(db)
    declared = db.value("SELECT id FROM contributor WHERE db_role = %s", (REVIEWER,))
    batch = db.value(
        """
        INSERT INTO import_batch (citation_id, owner_id, procedure, scope)
        VALUES (%s, %s, 'procédure', '{}') RETURNING id
        """,
        (citation, declared),
    )
    owner_role = db.value(
        """
        SELECT c.db_role::text FROM import_batch AS b JOIN contributor AS c ON c.id = b.owner_id
        WHERE b.id = %s
        """,
        (batch,),
    )
    assert owner_role == AGENT
