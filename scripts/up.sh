#!/usr/bin/env bash
# Start the Rased central stack (rased-api + rased-ui). SQLite, no external DB.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f ".env" ]; then
  echo "Creating .env from .env.example (edit secrets before exposing)."
  cp .env.example .env
fi

if [ -f "web/dist/index.html" ]; then
  # nginx (uid 101) must be able to read the built files.
  chmod -R a+rX web/dist 2>/dev/null || true
else
  echo "WARNING: web/dist not found. Build the UI first:  cd web && npm install && npm run build"
fi

echo "==> Starting Rased (API:8002, UI:8082)..."
docker compose up -d --build "$@"

# Re-bind the UI to the current build (a re-transferred dir gets a new inode).
docker compose up -d --force-recreate rased-ui >/dev/null 2>&1 || true

echo ""
echo "URLs:"
echo "  Rased UI:  http://localhost:8082"
echo "  Rased API: http://localhost:8002/docs"
