"""Rien n'est effacé (P7) : suppression et troncature refusées (docs/schema.md, §1, §5.3, E8)."""

import pytest
from psycopg import errors, sql

from tests.db import factories as f
from tests.db.support import AGENT, Db, refused


def test_import_role_has_no_delete_privilege(db: Db) -> None:
    db.role(AGENT)
    subject = f.entity(db)
    with refused(db, errors.InsufficientPrivilege):
        db.execute("DELETE FROM entity WHERE id = %s", (subject,))


def test_delete_is_refused_even_for_superuser(db: Db) -> None:
    """Le trigger refuse là où les droits ne suffisent pas (propriétaire, superutilisateur)."""
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.role(None)
    with refused(db, errors.RestrictViolation, "no_delete"):
        db.execute("DELETE FROM name_assertion WHERE id = %s", (assertion_id,))
    with refused(db, errors.RestrictViolation, "no_delete"):
        db.execute("DELETE FROM revision WHERE true")


@pytest.mark.parametrize("table", ["entity", "revision", "observation", "observation_default"])
def test_truncate_is_refused(db: Db, table: str) -> None:
    """Même en cascade : chaque table visée refuse avant d'être vidée."""
    with refused(db, errors.RestrictViolation, "no_delete"):
        db.execute(sql.SQL("TRUNCATE {} CASCADE").format(sql.Identifier(table)))


def test_every_table_refuses_delete_and_truncate(db: Db) -> None:
    """Toute table du schéma porte les deux triggers (les partitions héritent du premier)."""
    missing = db.value(
        """
        SELECT coalesce(array_agg(c.relname ORDER BY c.relname), '{}')
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind IN ('r', 'p')
          AND c.relowner = 'atlas_owner'::regrole
          AND NOT (
            EXISTS (SELECT FROM pg_trigger WHERE tgrelid = c.oid AND tgname = 'no_delete')
            AND EXISTS (SELECT FROM pg_trigger WHERE tgrelid = c.oid AND tgname = 'no_truncate')
          )
        """
    )
    assert missing == []


def test_citation_link_removal_needs_a_reason(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    second = f.cite(db, assertion_id)
    with refused(db, errors.RestrictViolation, "no_delete"):
        db.execute("DELETE FROM assertion_citation WHERE citation_id = %s", (second,))


def test_citation_link_removal_keeps_at_least_one_citation(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.context("reason", "citation erronée")
    with refused(db, errors.CheckViolation, "assertion_requires_citation"):
        db.execute("DELETE FROM assertion_citation WHERE assertion_id = %s", (assertion_id,))
        db.check_deferred()


def test_citation_link_removal_in_revised_transaction_is_accepted(db: Db) -> None:
    """Cas valide (E7) : un motif, et une autre citation qui reste."""
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    second = f.cite(db, assertion_id)
    db.context("reason", "citation remplacée")
    db.execute("DELETE FROM assertion_citation WHERE citation_id = %s", (second,))
    db.check_deferred()
    remaining = db.value(
        "SELECT count(*) FROM assertion_citation WHERE assertion_id = %s", (assertion_id,)
    )
    assert remaining == 1
