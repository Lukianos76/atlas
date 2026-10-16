#!/usr/bin/env bash
# Garde-fous des migrations (CLAUDE.md, règle 6 ; ADR 0010) :
# 1. immuabilité : aucune migration existant sur main n'est modifiée, renommée ou supprimée ;
# 2. en avant uniquement : la section `-- migrate:down` ne contient que des commentaires.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO_ROOT"

status=0

base="$(base_ref)"
if [ -z "$base" ]; then
  echo "Immuabilité : aucune branche main de référence, contrôle sans objet."
else
  changed="$(git diff --name-only --diff-filter=MDR "$base"...HEAD -- db/migrations)"
  # Les modifications non commitées comptent aussi.
  changed+="$(git diff --name-only --diff-filter=MDR HEAD -- db/migrations)"
  # Fichiers suivis sur la base de référence uniquement.
  tracked_on_base="$(git ls-tree -r --name-only "$base" -- db/migrations)"
  offending=""
  for file in $changed; do
    if grep -qxF "$file" <<<"$tracked_on_base"; then
      offending+="  $file"$'\n'
    fi
  done
  if [ -n "$offending" ]; then
    echo "Immuabilité : migrations déjà présentes sur $base modifiées, renommées ou supprimées :" >&2
    printf '%s' "$offending" >&2
    echo "Toute évolution du schéma passe par une nouvelle migration." >&2
    status=1
  else
    echo "Immuabilité : OK (référence $base)."
  fi
fi

for file in db/migrations/*.sql; do
  [ -e "$file" ] || continue
  if ! grep -q '^-- migrate:up' "$file" || ! grep -q '^-- migrate:down' "$file"; then
    echo "$file : sections -- migrate:up et -- migrate:down obligatoires." >&2
    status=1
    continue
  fi
  # Lignes non vides et non commentées après `-- migrate:down`.
  body="$(sed -n '/^-- migrate:down/,$p' "$file" | tail -n +2 | grep -vE '^[[:space:]]*(--.*)?$' || true)"
  if [ -n "$body" ]; then
    echo "$file : la section -- migrate:down doit rester vide (migrations en avant uniquement)." >&2
    status=1
  fi
done
[ "$status" -eq 0 ] && echo "En avant uniquement : OK."

exit "$status"
