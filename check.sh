#!/usr/bin/env bash
# Lance toutes les vérifications du repo (CLAUDE.md, règle 4).
# Usage : bash check.sh [--web] [--pipelines] [--db] [--reuse]   (sans option : tout)
# Chaque étape est lancée même si une précédente échoue ; le récapitulatif final
# indique OK, ÉCHEC ou NON LANCÉ, et le code de sortie est non nul si une étape n'est pas OK.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"
cd "$REPO_ROOT"

run_web=0 run_pipelines=0 run_db=0 run_reuse=0
if [ "$#" -eq 0 ]; then
  run_web=1 run_pipelines=1 run_db=1 run_reuse=1
fi
for arg in "$@"; do
  case "$arg" in
    --web) run_web=1 ;;
    --pipelines) run_pipelines=1 ;;
    --db) run_db=1 ;;
    --reuse) run_reuse=1 ;;
    *) echo "Option inconnue : $arg" >&2; exit 2 ;;
  esac
done

results=()
failed=0

record() { # record <statut> <nom>
  results+=("$1|$2")
  [ "$1" = OK ] || failed=1
}

step() { # step <nom> <commande...> : lance la commande et enregistre son résultat
  local name="$1"
  shift
  echo
  echo "=== $name"
  if "$@"; then
    record OK "$name"
  else
    record "ÉCHEC" "$name"
  fi
}

skip() { # skip <nom> <raison>
  record "NON LANCÉ" "$1 ($2)"
}

# --- Commun -----------------------------------------------------------------
check_node_major() {
  local expected actual
  expected="$(tr -d '[:space:]' <.node-version)"
  actual="$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "$actual" != "$expected" ]; then
    echo "Node $expected attendu (.node-version), trouvé : ${actual:-absent}." >&2
    return 1
  fi
  echo "Node $actual."
}

# --- Front ------------------------------------------------------------------
web() { pnpm --dir apps/web "$@"; }

if [ "$run_web" -eq 1 ]; then
  step "commun : version de Node" check_node_major
  if command -v pnpm >/dev/null; then
    step "web : installation" web install --frozen-lockfile
    step "web : types (tsc)" web run typecheck
    step "web : lint et formatage (Biome)" web run lint
    step "web : tests unitaires (Vitest)" web run test
    step "web : build (Vite)" web exec vite build
    step "web : bout en bout (Playwright)" web run e2e
  else
    skip "web" "pnpm absent"
  fi
fi

# --- Pipelines --------------------------------------------------------------
pipe() { uv run --directory pipelines --locked "$@"; }

if [ "$run_pipelines" -eq 1 ]; then
  if command -v uv >/dev/null; then
    step "pipelines : installation" uv sync --directory pipelines --locked
    step "pipelines : formatage (Ruff)" pipe ruff format --check .
    step "pipelines : lint (Ruff)" pipe ruff check .
    step "pipelines : types (pyright strict)" pipe pyright
    step "pipelines : tests (pytest)" pipe pytest
  else
    skip "pipelines" "uv absent"
  fi
fi

# --- Base -------------------------------------------------------------------
# Les migrations sont appliquées à une base jetable `atlas_check`, créée dans
# db-dev, éprouvée par les tests des invariants, puis supprimée. check ne touche
# jamais la base de référence.
check_db_url() {
  local env_file="$REPO_ROOT/.env"
  [ -f "$env_file" ] || env_file="$REPO_ROOT/.env.example"
  # shellcheck disable=SC1090
  (set -a; source "$env_file"; echo "postgres://${ATLAS_DEV_USER}:${ATLAS_DEV_PASSWORD}@db-dev:5432/atlas_check?sslmode=disable")
}

dbmate_check() { compose run --rm -e DATABASE_URL="$(check_db_url)" dbmate-dev "$@"; }

migrate_check_db() {
  dbmate_check drop >/dev/null 2>&1 || true
  dbmate_check create &&
    dbmate_check up &&
    dbmate_check status --exit-code
}

# Tests des invariants du schéma (pipelines/tests/db), sur la base jetable, avec les
# identifiants des rôles d'essai.
test_check_db() {
  local env_file="$REPO_ROOT/.env"
  [ -f "$env_file" ] || env_file="$REPO_ROOT/.env.example"
  # shellcheck disable=SC1090
  (set -a; source "$env_file"; ATLAS_TEST_DB=atlas_check pipe pytest -m db)
}

if [ "$run_db" -eq 1 ]; then
  step "db : garde-fous des migrations" bash scripts/check-migrations.sh
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    step "db : démarrage de db-dev" compose up --detach --wait db-dev
    step "db : migrations sur une base jetable" migrate_check_db
    step "db : rôles de connexion d'essai" bash scripts/db-dev-roles.sh atlas_check
    if command -v uv >/dev/null; then
      step "db : tests des invariants (pytest)" test_check_db
    else
      record "ÉCHEC" "db : uv absent, invariants du schéma non testés"
    fi
    step "db : suppression de la base jetable" dbmate_check drop
  else
    record "ÉCHEC" "db : Docker absent ou arrêté, migrations non vérifiées"
  fi
fi

# --- Licences ---------------------------------------------------------------
# Conformité à la spécification REUSE (ADR 0011). L'outil est épinglé ; l'extra
# charset-normalizer évite de dépendre de libmagic, absente sous Windows.
if [ "$run_reuse" -eq 1 ]; then
  if command -v uv >/dev/null; then
    step "licences : conformité REUSE" uvx --from "reuse[charset-normalizer]==6.2.0" reuse lint
  else
    skip "licences" "uv absent"
  fi
fi

# --- Récapitulatif ----------------------------------------------------------
echo
echo "=== Récapitulatif"
for entry in "${results[@]}"; do
  printf '%s\t%s\n' "${entry%%|*}" "${entry#*|}"
done
exit "$failed"
