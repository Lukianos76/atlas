"""Durcissement des droits (docs/schema.md, §5.10, §5.11, §5.13, E14).

Trois contournements fermés : un objet temporaire qui masquerait une table du schéma
ou porterait un trigger, une correction qui garderait une observation validée, un
rapport de validation réécrit par un autre contributeur que le responsable du lot.
"""

import pytest
from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, REVIEWER, Db, refused

STATUS = "SELECT observation_review_status(%s, %s)::text"
REPORT = "UPDATE import_batch SET validation_report = %s WHERE id = %s"


@pytest.mark.parametrize("role", [AGENT, REVIEWER])
def test_roles_cannot_create_temporary_objects(db: Db, role: str) -> None:
    db.role(role)
    with refused(db, errors.InsufficientPrivilege):
        db.execute("CREATE TEMPORARY TABLE contributor (id integer, db_role text)")


def test_guards_have_a_fixed_search_path(db: Db) -> None:
    configs = db.conn.execute(
        """
        SELECT proname, proconfig FROM pg_proc
        WHERE proname IN ('current_contributor', 'batch_open_to_caller',
                          'check_review_status_transition')
        ORDER BY proname
        """
    ).fetchall()
    assert [name for name, _ in configs] == [
        "batch_open_to_caller",
        "check_review_status_transition",
        "current_contributor",
    ]
    for name, config in configs:
        assert config == ["search_path=public, pg_catalog, pg_temp"], name


def test_correction_ignores_a_requested_status(db: Db) -> None:
    """Demander `validated` en corrigeant une observation validée ne la garde pas validée."""
    variable = f.variable(db)
    db.role(AGENT)
    observation = f.observation(db, variable, f.entity(db))
    db.check_deferred()
    db.role(REVIEWER)
    db.execute(
        "SELECT set_observation_review_status(%s, %s, 'validated', NULL)",
        (variable, observation),
    )
    db.role(AGENT)
    db.context("reason", "valeur rectifiée")
    db.context("review_status", "validated")
    db.execute(
        "UPDATE observation SET value = 1001 WHERE variable_id = %s AND id = %s",
        (variable, observation),
    )
    assert db.value(STATUS, (variable, observation)) == "proposed"


def test_report_belongs_to_owner_and_review_role(db: Db) -> None:
    # Un rôle d'import n'écrit pas le rapport du lot d'un autre contributeur.
    db.role(REVIEWER)
    other_batch = f.import_batch(db)
    db.role(AGENT)
    with refused(db, errors.InsufficientPrivilege, "batch_report_owner"):
        db.execute(REPORT, ('{"contrôles": "réécrits"}', other_batch))

    # Le responsable écrit le sien ; le rôle de vérification le complète.
    batch = f.import_batch(db)
    db.execute(REPORT, ('{"contrôles": "ok"}', batch))
    db.role(REVIEWER)
    db.execute(REPORT, ('{"contrôles": "ok", "échantillon": "vérifié"}', batch))
