#!/usr/bin/env bash
# Migre la base de référence (ADR 0010). Refusé hors de `main`, avec des
# modifications non commitées, ou si `main` n'est pas à jour avec `origin/main`.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO_ROOT"

branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != main ]; then
  echo "Refusé : la base de référence ne se migre que depuis main (branche courante : $branch)." >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Refusé : l'arbre de travail contient des modifications non commitées." >&2
  exit 1
fi
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet origin main
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "Refusé : main n'est pas identique à origin/main." >&2
    exit 1
  fi
fi

compose up --detach --wait db-ref
compose run --rm dbmate-ref up
compose run --rm dbmate-ref status
