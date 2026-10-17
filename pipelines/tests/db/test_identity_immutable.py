"""Identités et contenus immuables : entités, événements, dates, citations
(docs/schema.md, §5.1, §5.2, N7)."""

from typing import LiteralString

from psycopg import errors, sql

from tests.db import factories as f
from tests.db.support import AGENT, J2000, Db, refused


def test_identities_and_immutable_contents_cannot_be_updated(db: Db) -> None:
    db.role(AGENT)
    targets: dict[str, tuple[LiteralString, int]] = {
        "entity": ("entity_category_id = entity_category_id", f.entity(db)),
        # Seule mise à jour admise par une identité ALWAYS : elle changerait l'identifiant.
        "event": ("id = DEFAULT", f.dated_event(db)),
        "historical_date": ("original_expression = 'réécrite'", f.historical_date(db, J2000)),
        "citation": ("locator = 'p. 2'", f.citation(db)),
    }
    db.role(None)
    for table, (assignment, row_id) in targets.items():
        with refused(db, errors.RestrictViolation, "immutable_row"):
            db.execute(
                sql.SQL("UPDATE {} SET {} WHERE id = %s").format(
                    sql.Identifier(table), sql.SQL(assignment)
                ),
                (row_id,),
            )


def test_a_correction_creates_a_new_row(db: Db) -> None:
    """Cas valide : corriger une citation, c'est en créer une autre et changer le lien (§5.2)."""
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    wrong = db.value(
        "SELECT citation_id FROM assertion_citation WHERE assertion_id = %s", (assertion_id,)
    )
    f.cite(db, assertion_id)
    db.context("reason", "localisateur erroné")
    db.execute("DELETE FROM assertion_citation WHERE citation_id = %s", (wrong,))
    db.check_deferred()
