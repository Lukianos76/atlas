"""Une géométrie ne se corrige jamais sur place (docs/schema.md, §5.4)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, J2000, Db, refused


def test_geometry_update_is_refused(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.geometry(db, f.entity(db))
    with refused(db, errors.RestrictViolation, "immutable_row"):
        db.execute(
            "UPDATE geometry_assertion SET shape = ST_Translate(shape, 0.01, 0) WHERE id = %s",
            (assertion_id,),
        )
    with refused(db, errors.RestrictViolation, "immutable_row"):
        db.execute(
            "UPDATE geometry_assertion SET source_crs = 'EPSG:4326' WHERE id = %s",
            (assertion_id,),
        )


def test_closing_the_period_of_a_geometry_is_accepted(db: Db) -> None:
    """Cas valide : quand une limite change, on clôt la période dans le tronc (modèle §6.2)."""
    db.role(AGENT)
    assertion_id = f.geometry(db, f.entity(db))
    end = J2000 + 365
    db.context("reason", "limite modifiée")
    db.execute(
        """
        UPDATE assertion
        SET end_kind = 'dated', end_earliest = %s, end_latest = %s, end_date_id = %s
        WHERE id = %s
        """,
        (end, end, f.historical_date(db, end), assertion_id),
    )
    db.check_deferred()
    core = db.value("SELECT core_range::text FROM assertion WHERE id = %s", (assertion_id,))
    assert core == f"[{J2000},{end})"


def test_correcting_a_geometry_means_a_new_assertion(db: Db) -> None:
    """Cas valide : la correction retire l'assertion erronée et en crée une nouvelle."""
    db.role(AGENT)
    subject = f.entity(db)
    f.geometry(db, subject)
    f.geometry(db, subject)
    db.check_deferred()
