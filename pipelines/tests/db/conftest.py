"""Connexions aux bases de test des invariants du schéma.

Ces tests visent une base jetable de db-dev, migrée et dotée des rôles d'essai :
`check.sh --db` la crée, la désigne par `ATLAS_TEST_DB`, puis la supprime. Sans cette
variable, ils sont ignorés.
"""

import os
from collections.abc import Generator
from pathlib import Path
from typing import Any

import psycopg
import pytest

from tests.db.support import AGENT, REVIEWER, Db, conninfo

HERE = Path(__file__).parent


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if item.path.is_relative_to(HERE):
            item.add_marker(pytest.mark.db)


def _connect(user: str, password_variable: str) -> psycopg.Connection[tuple[Any, ...]]:
    return psycopg.connect(conninfo(user, password_variable))


@pytest.fixture
def db() -> Generator[Db]:
    """Superutilisateur de db-dev, dans une transaction annulée à la fin du test."""
    conn = _connect(os.environ.get("ATLAS_DEV_USER", "atlas"), "ATLAS_DEV_PASSWORD")
    try:
        yield Db(conn)
    finally:
        conn.rollback()
        conn.close()


@pytest.fixture
def agent_login() -> Generator[Db]:
    """Connexion propre du rôle d'import d'essai, pour les tests qui valident leurs écritures."""
    conn = _connect(AGENT, "ATLAS_DEV_AGENT_PASSWORD")
    try:
        yield Db(conn)
    finally:
        conn.rollback()
        conn.close()


@pytest.fixture
def reviewer_login() -> Generator[Db]:
    """Connexion propre du rôle de vérification d'essai."""
    conn = _connect(REVIEWER, "ATLAS_DEV_REVIEWER_PASSWORD")
    try:
        yield Db(conn)
    finally:
        conn.rollback()
        conn.close()
