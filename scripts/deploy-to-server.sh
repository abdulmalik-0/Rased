#!/usr/bin/env bash
# Package & sync the deployable files to a destination (local path or remote ssh).
# Includes .env and the built web/dist (both gitignored); excludes source/cache.
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

if [ ! -f "$ROOT/web/dist/index.html" ]; then
  echo "ERROR: web/dist not found. Build the UI first:"
  echo "  cd web && npm install && VITE_BACKEND_URL=http://YOUR_IP:8002 npm run build"
  exit 1
fi
[ -f "$ROOT/.env" ] || echo "WARNING: .env not found in project root (the server will need one)."

echo "==> Rased deploy -> $DEST"

# 1) Everything except UI source trees, git, caches, and local data.
rsync -az --info=stats1 \
  --exclude='.git/' \
  --exclude='frontend/' \
  --exclude='web/node_modules/' \
  --exclude='web/src/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='.venv/' \
  --exclude='*.db' \
  --exclude='*.db-wal' \
  --exclude='*.db-shm' \
  "$ROOT/" "$DEST/"

# 2) Only the built web app, preserving its path (web/dist).
rsync -aRz "$ROOT/./web/dist/" "$DEST/"

echo ""
echo "Done. Next, on the server:"
echo "  cd <dest>"
echo "  sed -i 's/\\r\$//' .env   # fix CRLF if packaged on Windows"
echo "  chmod +x scripts/*.sh"
echo "  ./scripts/up.sh"
