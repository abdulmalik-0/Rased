#!/usr/bin/env bash
# Rased — ONE-COMMAND central install using prebuilt GHCR images (no clone, no npm):
#
#   curl -fsSL https://raw.githubusercontent.com/abdulmalik-0/Rased/main/scripts/bootstrap-central.sh | bash
#
# Installs Docker if missing, generates .env with random secrets (asks only for the
# server IP), pulls the images, and starts the stack.
set -euo pipefail

RAW="${RASED_RAW:-https://raw.githubusercontent.com/abdulmalik-0/Rased/main}"
DIR="${RASED_DIR:-$HOME/rased}"

say()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 && SUDO="sudo" || { warn "Run as root or install sudo."; exit 1; }
fi

command -v curl >/dev/null 2>&1 || { warn "curl is required."; exit 1; }
if ! command -v docker >/dev/null 2>&1; then
  say "Installing Docker ..."
  curl -fsSL https://get.docker.com | $SUDO sh
fi
$SUDO systemctl enable --now docker >/dev/null 2>&1 || true

rand()      { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
detect_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }

mkdir -p "$DIR"
cd "$DIR"
say "Fetching docker-compose.images.yml ..."
curl -fsSL "$RAW/docker-compose.images.yml" -o docker-compose.yml

if [ ! -f .env ]; then
  DEF_IP="$(detect_ip)"; DEF_IP="${DEF_IP:-192.168.1.10}"
  read -r -p "Server IP [${DEF_IP}]: " IP || true; IP="${IP:-$DEF_IP}"
  read -r -p "UPS (NUT) host/IP (Enter to skip): " NUTH || true
  {
    echo "RASED_HOST_ID=central"
    echo "RASED_HOST_NAME=My Server"
    echo "RASED_PUBLIC_BASE_URL=http://${IP}:8002"
    echo "RASED_CORS_ORIGINS=http://${IP}:8082,http://localhost:8082"
    echo "JWT_SECRET=$(rand)"
    echo "ENCRYPTION_KEY=$(rand)"
    echo "AGENT_TOKEN=$(rand)"
    echo "NUT_HOST=${NUTH:-host.docker.internal}"
    echo "NUT_PORT=3493"
    echo "NUT_UPS_NAME=ups"
  } > .env
  say "Wrote .env with random secrets."
fi

say "Pulling images & starting ..."
$SUDO docker compose pull
$SUDO docker compose up -d

HOSTPART="$(grep -E '^RASED_PUBLIC_BASE_URL=' .env | sed -E 's#.*//([^:/]+).*#\1#')"
echo ""
say "Done!"
echo "  Dashboard : http://${HOSTPART:-localhost}:8082"
echo "  The FIRST account you register becomes the admin."
