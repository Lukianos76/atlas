"""Un événement a au moins une assertion de date, citée (docs/schema.md, §5.5, A4, N10)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, Db, refused


def test_event_without_date_is_refused(db: Db) -> None:
    db.role(AGENT)
    with refused(db, errors.CheckViolation, "event_requires_date"):
        f.event(db)
        db.check_deferred()


def test_event_with_cited_date_is_accepted(db: Db) -> None:
    db.role(AGENT)
    event_id = f.dated_event(db)
    db.check_deferred()
    copied = db.conn.execute(
        """
        SELECT d.earliest = h.earliest AND d.latest = h.latest
        FROM assertion AS a
        JOIN event_date_assertion AS d ON d.id = a.id
        JOIN historical_date AS h ON h.id = d.date_id
        WHERE a.subject_event_id = %s
        """,
        (event_id,),
    ).fetchone()
    assert copied == (True,)


def test_event_assertion_with_period_is_refused(db: Db) -> None:
    """Une assertion sur un événement n'a pas de période : elle se déduit de sa date (N1)."""
    db.role(AGENT)
    event_id = f.dated_event(db)
    with refused(db, errors.CheckViolation, "assertion_period_iff_not_event"):
        db.execute(
            """
            INSERT INTO assertion (
              assertion_type, subject_event_id, start_kind, start_earliest, start_latest,
              start_date_id, end_kind, certainty
            ) VALUES ('participation', %s, 'dated', %s, %s, %s, 'ongoing', 'established')
            """,
            (event_id, J2000, J2000, f.historical_date(db, J2000)),
        )
