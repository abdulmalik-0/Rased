#!/usr/bin/env bash
# Applies all Rased SQL migrations (in order) to the local Supabase Postgres
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIG="$ROOT/supabase/migrations"

if ! docker ps --filter "name=supabase-db" --format '{{.Names}}' | grep -q '^supabase-db$'; then
  echo "ERROR: container supabase-db is not running. Start the stack first: ./scripts/up.sh"
  exit 1
fi

shopt -s nullglob
files=("$MIG"/*.sql)
if [ ${#files[@]} -eq 0 ]; then
  echo "ERROR: no .sql migrations found in $MIG"
  exit 1
fi

for f in "${files[@]}"; do
  echo "==> Applying $(basename "$f") ..."
  docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f"
done

echo "    All migrations complete."
