"""Règles du tronc commun et des types d'assertion (docs/schema.md, §5.3 à §5.6)."""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, Db, refused


def test_assertion_without_type_row_is_refused(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.assertion(db, "name", subject_entity=f.entity(db))
    f.cite(db, assertion_id)
    with refused(db, errors.CheckViolation, "assertion_requires_content"):
        db.check_deferred()


def test_type_row_must_match_trunk_type(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.assertion(db, "legal_status", subject_entity=f.entity(db))
    with refused(db, errors.ForeignKeyViolation):
        db.execute(
            """
            INSERT INTO name_assertion (id, text, language, script, name_type)
            VALUES (%s, 'nom', 'fr', 'Latn', 'common')
            """,
            (assertion_id,),
        )


def test_subject_must_match_type(db: Db) -> None:
    db.role(AGENT)
    subject = f.entity(db)
    with refused(db, errors.CheckViolation, "assertion_subject_matches_type"):
        f.assertion(db, "system_validity", subject_entity=subject)
    system = f.division_system(db)
    f.assertion(db, "system_validity", subject_system=system)


def test_legal_status_requires_authority(db: Db) -> None:
    db.role(AGENT)
    subject, authority = f.entity(db), f.entity(db)

    def legal_status(authority_id: int | None) -> None:
        assertion_id = f.assertion(
            db, "legal_status", subject_entity=subject, authority=authority_id
        )
        db.execute(
            "INSERT INTO legal_status_assertion (id, legal_status) VALUES (%s, 'commune')",
            (assertion_id,),
        )
        f.cite(db, assertion_id)

    with refused(db, errors.CheckViolation, "assertion_authority"):
        legal_status(None)
        db.check_deferred()
    legal_status(authority)
    db.check_deferred()


def test_official_name_requires_authority(db: Db) -> None:
    db.role(AGENT)
    subject = f.entity(db)
    with refused(db, errors.CheckViolation, "assertion_authority"):
        f.name(db, subject, name_type="official")
        db.check_deferred()
    f.name(db, subject, name_type="official", authority=f.entity(db))
    db.check_deferred()


def test_membership_authority_is_read_from_system(db: Db) -> None:
    """L'autorité d'une appartenance n'est pas recopiée (A15)."""
    db.role(AGENT)
    level = f.level(db)
    subject = f.entity(db)

    def membership(authority_id: int | None) -> None:
        assertion_id = f.assertion(
            db, "system_membership", subject_entity=subject, authority=authority_id
        )
        db.execute(
            "INSERT INTO system_membership_assertion (id, level_id) VALUES (%s, %s)",
            (assertion_id, level),
        )
        f.cite(db, assertion_id)

    with refused(db, errors.CheckViolation, "assertion_authority"):
        membership(f.entity(db))
        db.check_deferred()
    membership(None)
    db.check_deferred()


def test_transfer_share_requires_share_citation(db: Db) -> None:
    db.role(AGENT)
    level = f.level(db)
    event_id = f.dated_event(db)
    origin, destination = f.entity(db), f.entity(db)

    def transfer(share_role: str) -> None:
        assertion_id = f.assertion(db, "transfer", subject_event=event_id)
        db.execute(
            """
            INSERT INTO transfer_assertion (
              id, from_entity_id, from_level_id, to_entity_id, to_level_id,
              territory, share, share_basis
            ) VALUES (%s, %s, %s, %s, %s, 'partial', 0.25, 'area')
            """,
            (assertion_id, origin, level, destination, level),
        )
        f.cite(db, assertion_id, role=share_role)

    with refused(db, errors.CheckViolation, "transfer_share_citation"):
        transfer("value")
        db.check_deferred()
    transfer("share")
    db.check_deferred()


def test_whole_transfer_has_no_share(db: Db) -> None:
    db.role(AGENT)
    level = f.level(db)
    assertion_id = f.assertion(db, "transfer", subject_event=f.dated_event(db))
    with refused(db, errors.CheckViolation, "transfer_assertion_share_partial"):
        db.execute(
            """
            INSERT INTO transfer_assertion (
              id, from_entity_id, from_level_id, to_entity_id, to_level_id,
              territory, share, share_basis
            ) VALUES (%s, %s, %s, %s, %s, 'whole', 0.5, 'area')
            """,
            (assertion_id, f.entity(db), level, f.entity(db), level),
        )
