"""L'instantané d'une révision référence la géométrie sans la recopier
(docs/schema.md, §5.11)."""

from tests.db import factories as f
from tests.db.support import AGENT, Db


def snapshot(db: Db, assertion_id: int) -> dict[str, object]:
    return db.value("SELECT snapshot FROM revision WHERE assertion_id = %s", (assertion_id,))


def test_geometry_snapshot_has_no_shape(db: Db) -> None:
    db.role(AGENT)
    assertion_id = f.geometry(db, f.entity(db))
    db.check_deferred()
    revision = snapshot(db, assertion_id)
    content = revision["content"]
    trunk = revision["assertion"]
    assert isinstance(content, dict) and isinstance(trunk, dict)
    assert "shape" not in content
    assert content["source_crs"] == "EPSG:2154"
    assert trunk["id"] == assertion_id


def test_small_contents_are_copied(db: Db) -> None:
    """Cas valide : un nom, petit contenu, est recopié dans l'instantané avec ses citations."""
    db.role(AGENT)
    assertion_id = f.name(db, f.entity(db))
    db.check_deferred()
    revision = snapshot(db, assertion_id)
    content = revision["content"]
    citations = revision["citations"]
    assert isinstance(content, dict) and isinstance(citations, list)
    text = db.value("SELECT text FROM name_assertion WHERE id = %s", (assertion_id,))
    assert content["text"] == text
    citation = db.value(
        "SELECT citation_id FROM assertion_citation WHERE assertion_id = %s", (assertion_id,)
    )
    assert citations == [{"citation_id": citation, "citation_role": "value"}]
