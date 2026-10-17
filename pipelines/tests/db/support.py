"""Outils communs aux tests des invariants du schéma (docs/schema.md).

Chaque test reçoit une connexion du superutilisateur de la base de développement, dans
une transaction annulée à la fin. Il prend l'identité d'un rôle de connexion d'essai
par `SET ROLE` : `current_user` est alors ce rôle, comme pour une vraie connexion.
"""

import os
import uuid
from collections.abc import Generator
from contextlib import contextmanager
from typing import Any

import psycopg
import pytest
from psycopg import sql
from psycopg.abc import Params, QueryNoTemplate
from psycopg.conninfo import make_conninfo

# Rôles de connexion d'essai, créés par `scripts/db-dev-roles.sh`.
AGENT = "atlas_dev_agent"
REVIEWER = "atlas_dev_reviewer"

# Jour julien du 1er janvier 2000 : les dates d'essai en sont des décalages.
J2000 = 2451545


def unique(prefix: str) -> str:
    """Valeur unique (code, localisateur, titre) : les tests ne dépendent pas des autres."""
    return f"{prefix}-{uuid.uuid4().hex[:12]}"


def conninfo(user: str, password_variable: str) -> str:
    """Paramètres de connexion à la base de test, ou test ignoré si elle n'est pas désignée."""
    database = os.environ.get("ATLAS_TEST_DB")
    if not database:
        pytest.skip("ATLAS_TEST_DB non renseignée : tests de la base lancés par check.sh --db")
    return make_conninfo(
        host="127.0.0.1",
        port=os.environ.get("ATLAS_DEV_PORT", "5433"),
        dbname=database,
        user=user,
        password=os.environ[password_variable],
    )


class Db:
    """Connexion de test : requêtes, rôle courant et contexte déclaratif `atlas.*`."""

    def __init__(self, conn: psycopg.Connection[tuple[Any, ...]]) -> None:
        self.conn = conn
        self.current_role: str | None = None

    def execute(self, query: QueryNoTemplate, params: Params | None = None) -> None:
        self.conn.execute(query, params)

    def value(self, query: QueryNoTemplate, params: Params | None = None) -> Any:
        """Première colonne de la première ligne."""
        row = self.conn.execute(query, params).fetchone()
        assert row is not None, "la requête ne renvoie aucune ligne"
        return row[0]

    def role(self, name: str | None) -> None:
        """Prend l'identité d'un rôle de connexion ; `None` revient au superutilisateur."""
        if name is None:
            self.conn.execute("RESET ROLE")
        else:
            self.conn.execute(sql.SQL("SET ROLE {}").format(sql.Identifier(name)))
        self.current_role = name

    @contextmanager
    def as_role(self, name: str | None) -> Generator[None]:
        """Change de rôle le temps d'un bloc, puis revient au rôle précédent."""
        previous = self.current_role
        self.role(name)
        try:
            yield
        finally:
            self.role(previous)

    def context(self, name: str, value: str) -> None:
        """Équivalent de `SET LOCAL atlas.<name> = <value>` (§5.11)."""
        self.conn.execute("SELECT set_config(%s, %s, true)", (f"atlas.{name}", value))

    def check_deferred(self) -> None:
        """Déclenche les contrôles différés sans valider la transaction."""
        self.conn.execute("SET CONSTRAINTS ALL IMMEDIATE")


@contextmanager
def refused(db: Db, error: type[psycopg.Error], constraint: str | None = None) -> Generator[None]:
    """Le bloc doit être refusé par la base avec cette erreur (et cette contrainte).

    Le bloc s'exécute dans un point de sauvegarde : le refus n'interrompt pas la
    transaction du test, qui peut ensuite montrer le cas valide.
    """
    with pytest.raises(error) as info, db.conn.transaction():
        yield
    if constraint is not None:
        assert info.value.diag.constraint_name == constraint, str(info.value)
