#!/bin/sh
# Generate /config.js from the BACKEND_URL env var at container start, so a single
# prebuilt UI image works against any backend without rebuilding.
set -e
: "${BACKEND_URL:=}"
echo "window.__RASED_BACKEND__ = '${BACKEND_URL}';" \
  > /usr/share/nginx/html/config.js
