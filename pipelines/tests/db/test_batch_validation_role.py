"""Seul le rôle de vérification décide (docs/schema.md, §5.10, §5.13).

Le scénario complet passe par les connexions propres des deux rôles d'essai, chacune
validant ses écritures : c'est le cas réel d'un agent qui importe et d'un humain qui
vérifie. Les données sont uniques au test.
"""

from psycopg import errors

from tests.db import factories as f
from tests.db.support import AGENT, REVIEWER, Db, refused


def test_import_role_cannot_take_the_review_role(agent_login: Db) -> None:
    for target in ("atlas_review", REVIEWER):
        with refused(agent_login, errors.InsufficientPrivilege):
            agent_login.role(target)


def test_import_role_cannot_validate_an_assertion(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    with refused(db, errors.InsufficientPrivilege, "review_status_guard"):
        db.execute(
            "UPDATE assertion SET review_status = 'validated' WHERE id = %s", (assertion_id,)
        )


def test_review_role_validates_an_assertion(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.role(REVIEWER)
    db.execute("UPDATE assertion SET review_status = 'validated' WHERE id = %s", (assertion_id,))
    db.check_deferred()


def test_batch_decision_belongs_to_review_role(agent_login: Db, reviewer_login: Db) -> None:
    agent, reviewer = agent_login, reviewer_login

    # L'agent importe : un lot et une assertion du lot (E10).
    batch = f.import_batch(agent)
    agent.context("import_batch_id", str(batch))
    assertion_id = f.name(agent, f.entity(agent))
    agent.execute(
        'UPDATE import_batch SET validation_report = \'{"contrôles": "ok"}\' WHERE id = %s',
        (batch,),
    )
    agent.conn.commit()

    # Il ne peut pas valider son propre lot.
    with refused(agent, errors.InsufficientPrivilege, "batch_status_guard"):
        agent.execute("UPDATE import_batch SET batch_status = 'validated' WHERE id = %s", (batch,))
    agent.conn.rollback()

    # Le vérificateur valide : il est consigné, la révision du lot est écrite, et les
    # assertions du lot passent à `validated`.
    reviewer.execute("UPDATE import_batch SET batch_status = 'validated' WHERE id = %s", (batch,))
    reviewer.conn.commit()

    reviewer_id, reviewer_kind = reviewer.conn.execute(
        """
        SELECT b.reviewer_id = c.id, b.reviewer_kind::text
        FROM import_batch AS b, contributor AS c
        WHERE b.id = %s AND c.db_role = %s
        """,
        (batch, REVIEWER),
    ).fetchone() or (None, None)
    assert reviewer_id is True
    assert reviewer_kind == "human"
    batch_statuses = reviewer.conn.execute(
        """
        SELECT batch_status::text FROM revision
        WHERE import_batch_id = %s AND batch_status IS NOT NULL
        ORDER BY recorded_at, id
        """,
        (batch,),
    ).fetchall()
    assert [row[0] for row in batch_statuses] == ["proposed", "validated"]
    assert f.revisions(reviewer, assertion_id) == [
        ("create", "proposed"),
        ("review_status_change", "validated"),
    ]
    reviewer.conn.commit()
