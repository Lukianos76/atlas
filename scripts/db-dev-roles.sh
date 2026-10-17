#!/usr/bin/env bash
# Crée les rôles de connexion d'essai de la base de développement (docs/schema.md, §5.13)
# et enregistre leurs contributeurs dans la base indiquée. Ne vise que le service db-dev :
# ces rôles, aux mots de passe connus, n'existent jamais sur la base de référence.
# Usage : bash scripts/db-dev-roles.sh [base de db-dev]   (défaut : ATLAS_DEV_DB)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

env_file="$REPO_ROOT/.env"
[ -f "$env_file" ] || env_file="$REPO_ROOT/.env.example"
# shellcheck disable=SC1090
set -a && source "$env_file" && set +a

database="${1:-$ATLAS_DEV_DB}"

# Les rôles sont communs au serveur : création gardée, mot de passe resynchronisé.
# Les contributeurs sont propres à chaque base.
compose exec -T db-dev psql --quiet -v ON_ERROR_STOP=1 \
  -U "$ATLAS_DEV_USER" -d "$database" \
  -v agent_password="$ATLAS_DEV_AGENT_PASSWORD" \
  -v reviewer_password="$ATLAS_DEV_REVIEWER_PASSWORD" <<'SQL'
SET client_min_messages = warning;
SELECT 'CREATE ROLE atlas_dev_agent LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'atlas_dev_agent') \gexec
SELECT 'CREATE ROLE atlas_dev_reviewer LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'atlas_dev_reviewer') \gexec
SELECT format('ALTER ROLE atlas_dev_agent PASSWORD %L', :'agent_password') \gexec
SELECT format('ALTER ROLE atlas_dev_reviewer PASSWORD %L', :'reviewer_password') \gexec
GRANT atlas_import TO atlas_dev_agent;
GRANT atlas_review TO atlas_dev_reviewer;
INSERT INTO contributor (contributor_kind, display_name, db_role) VALUES
  ('agent', 'Agent d''essai (base de développement)', 'atlas_dev_agent'),
  ('human', 'Vérificateur d''essai (base de développement)', 'atlas_dev_reviewer')
ON CONFLICT (db_role) DO NOTHING;
SQL
echo "Rôles d'essai prêts dans $database."
