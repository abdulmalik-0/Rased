#!/usr/bin/env bash
# Downloads official Supabase self-hosted Docker files into supabase/docker/
# Required once before: docker compose up -d
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/supabase/docker"
TEMP="$ROOT/supabase/_upstream"

echo "==> Rased: Supabase Docker setup"

if [ -f "$TARGET/docker-compose.yml" ]; then
  echo "    supabase/docker already exists. Delete it to re-fetch."
  exit 0
fi

rm -rf "$TEMP"
echo "    Cloning supabase/supabase (docker folder only)..."
git clone --depth 1 --filter=blob:none --sparse https://github.com/supabase/supabase.git "$TEMP"
git -C "$TEMP" sparse-checkout set docker

rm -rf "$TARGET"
mkdir -p "$(dirname "$TARGET")"
mv "$TEMP/docker" "$TARGET"
rm -rf "$TEMP"

echo "    Done: $TARGET"
