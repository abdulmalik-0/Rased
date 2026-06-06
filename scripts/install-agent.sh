#!/usr/bin/env bash
# Rased — one-command installer for an AGENT (additional machine / LXC).
# Copy the Rased folder to the new machine first, then run this with the values
# shown in the dashboard's "Add device" screen. Missing values are asked for.
#
#   bash scripts/install-agent.sh --central http://CENTRAL_IP:8002 \
#        --token <AGENT_TOKEN> --jwt <JWT_SECRET> --id lxc-2 --name "LXC 2"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CENTRAL=""; TOKEN=""; JWT=""; ID=""; NAME=""; IP=""; PORT="8002"
while [ $# -gt 0 ]; do
  case "$1" in
    --central) CENTRAL="$2"; shift 2;;
    --token)   TOKEN="$2";   shift 2;;
    --jwt)     JWT="$2";     shift 2;;
    --id)      ID="$2";      shift 2;;
    --name)    NAME="$2";    shift 2;;
    --ip)      IP="$2";      shift 2;;
    --port)    PORT="$2";    shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

detect_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }
ask() { local p="$1" d="$2" v=""; read -r -p "$p" v || true; printf '%s' "${v:-$d}"; }

[ -n "$CENTRAL" ] || CENTRAL="$(ask 'Central API URL (http://CENTRAL_IP:8002): ' '')"
[ -n "$TOKEN" ]   || TOKEN="$(ask 'AGENT_TOKEN (from dashboard): ' '')"
[ -n "$JWT" ]     || JWT="$(ask 'JWT_SECRET (from dashboard): ' '')"
[ -n "$ID" ]      || ID="$(ask 'Unique host id [lxc-2]: ' 'lxc-2')"
[ -n "$NAME" ]    || NAME="$(ask 'Display name [LXC 2]: ' 'LXC 2')"
[ -n "$IP" ]      || IP="$(ask "This machine IP [$(detect_ip)]: " "$(detect_ip)")"

for v in CENTRAL TOKEN JWT ID IP; do
  if [ -z "${!v}" ]; then echo "ERROR: missing --${v,,}"; exit 1; fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: 'docker compose' is required. Install it first (curl -fsSL https://get.docker.com | sh)."
  exit 1
fi

CENTRAL_HOST="$(printf '%s' "$CENTRAL" | sed -E 's#https?://([^:/]+).*#\1#')"

cat > .env.agent <<EOF
RASED_API_PORT=${PORT}
RASED_HOST_ID=${ID}
RASED_HOST_NAME=${NAME}
RASED_PUBLIC_BASE_URL=http://${IP}:${PORT}
CENTRAL_INGEST_URL=${CENTRAL}
AGENT_TOKEN=${TOKEN}
JWT_SECRET=${JWT}
RASED_CORS_ORIGINS=http://${CENTRAL_HOST}:8082
NUT_HOST=host.docker.internal
NUT_PORT=3493
NUT_UPS_NAME=ups
EOF

echo "Wrote .env.agent. Building & starting the agent..."
docker compose --env-file .env.agent -f docker-compose.agent.yml up -d --build
echo ""
echo "Done. This machine will appear as the tab '${NAME}' in the dashboard within a few seconds."
