# Fonctions communes aux scripts du repo (à sourcer, pas à exécuter).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# docker compose avec le fichier d'identifiants local, ou `.env.example` à défaut
# (CI, premier lancement) : ce ne sont que des identifiants de bases locales.
compose() {
  local env_file="$REPO_ROOT/.env"
  [ -f "$env_file" ] || env_file="$REPO_ROOT/.env.example"
  docker compose --project-directory "$REPO_ROOT" --env-file "$env_file" "$@"
}

# Branche de référence pour les garde-fous : origin/main si le remote existe, sinon main.
base_ref() {
  if git -C "$REPO_ROOT" rev-parse --verify --quiet origin/main >/dev/null; then
    echo origin/main
  elif git -C "$REPO_ROOT" rev-parse --verify --quiet main >/dev/null; then
    echo main
  fi
}
