#!/usr/bin/env bash
# Package & sync the deployable files to a destination (local path or remote ssh).
# Includes .env and the built frontend/build/web (both gitignored); excludes source/cache.
#
# Usage:
#   ./scripts/deploy-to-server.sh /tmp/rased-pkg                              # local staging
#   ./scripts/deploy-to-server.sh atamimi@192.168.100.100:/home/atamimi/rased  # remote (ssh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-}"

if [ -z "$DEST" ]; then
  echo "Usage: $0 <dest-path | user@host:/path>"
  exit 1
fi

command -v rsync >/dev/null 2>&1 || { echo "ERROR: rsync is required (e.g. sudo apt install rsync)"; exit 1; }

if [ ! -f "$ROOT/frontend/build/web/index.html" ]; then
  echo "ERROR: frontend/build/web not found. Build first:"
  echo "  cd frontend && flutter build web --dart-define=BACKEND_URL=http://YOUR_IP:8002 --dart-define=SUPABASE_URL=http://YOUR_IP:8003 --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>"
  exit 1
fi
[ -f "$ROOT/.env" ] || echo "WARNING: .env not found in project root (the server will need one)."

echo "==> Rased deploy -> $DEST"

# 1) Everything except the frontend source tree, git, caches, and supabase runtime.
rsync -az --info=stats1 \
  --exclude='.git/' \
  --exclude='frontend/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='.venv/' \
  --exclude='supabase/_upstream/' \
  --exclude='supabase/docker/volumes/' \
  "$ROOT/" "$DEST/"

# 2) Only the built web app, preserving its path (frontend/build/web).
rsync -aRz "$ROOT/./frontend/build/web/" "$DEST/"

echo ""
echo "Done. Next, on the server:"
echo "  cd <dest>"
echo "  sed -i 's/\\r\$//' .env supabase/migrations/*.sql   # fix CRLF if packaged on Windows"
echo "  chmod +x scripts/*.sh"
echo "  ./scripts/up.sh && ./scripts/run-migration.sh"
