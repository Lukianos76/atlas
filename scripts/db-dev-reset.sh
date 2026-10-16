#!/usr/bin/env bash
# Recrée la base de développement jetable (ADR 0010) : supprime son conteneur et
# son volume, la redémarre vide, puis applique toutes les migrations de la branche.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

compose rm --stop --force --volumes db-dev
docker volume rm --force atlas_atlas-dev >/dev/null
compose up --detach --wait db-dev
compose run --rm dbmate-dev up
echo "Base de développement recréée et migrée."
