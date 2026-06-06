#!/usr/bin/env bash
# Start the full Rased + Supabase stack (Linux)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f "supabase/docker/docker-compose.yml" ]; then
  echo "Supabase docker files missing. Running setup..."
  bash "$ROOT/scripts/setup-supabase-docker.sh"
fi

if [ ! -f ".env" ]; then
  echo "Creating .env from .env.example ..."
  cp .env.example .env
  echo "Edit .env secrets before production use."
fi

if [ ! -f "frontend/build/web/index.html" ]; then
  echo "WARNING: frontend/build/web not found. Build the Flutter web app first (see README)."
else
  # Ensure the built web files are world-readable so the nginx container
  # (uid 101) can serve them — transfers from Windows often drop read perms.
  chmod -R a+rX frontend/build/web 2>/dev/null || true
fi

echo "==> Starting Rased stack (Kong:8003, API:8002, UI:8082)..."
docker compose up -d --build "$@"

# The UI bind-mounts frontend/build/web. After a re-transfer the directory gets
# a new inode, so the running container would keep serving the old (empty) mount
# and return 403. Force-recreate it to (re)bind to the current files.
docker compose up -d --force-recreate rased-ui >/dev/null 2>&1 || true

echo ""
echo "URLs:"
echo "  Rased UI:        http://localhost:8082"
echo "  Rased API:       http://localhost:8002/docs"
echo "  Supabase (Kong): http://localhost:8003"
echo ""
echo "Run migrations if first time: ./scripts/run-migration.sh"
