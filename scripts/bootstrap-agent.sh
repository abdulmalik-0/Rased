#!/usr/bin/env bash
# Rased — ONE-COMMAND agent bootstrap. Downloads Rased from GitHub and starts
# the agent on a new Linux machine. Values come from the dashboard "Add device":
#
#   curl -fsSL https://raw.githubusercontent.com/abdulmalik-0/Rased/main/scripts/bootstrap-agent.sh \
#     | bash -s -- --central http://CENTRAL_IP:8002 --token <AGENT_TOKEN> \
#                  --jwt <JWT_SECRET> --id lxc-2 --name "LXC 2"
#
# Override the source repo with:  RASED_REPO=https://github.com/you/fork.git
set -euo pipefail

REPO="${RASED_REPO:-https://github.com/abdulmalik-0/Rased.git}"
DIR="${RASED_DIR:-$HOME/rased}"

say()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }

command -v git >/dev/null 2>&1 || {
  warn "git is required:  sudo apt-get install -y git"; exit 1; }
if ! command -v docker >/dev/null 2>&1; then
  warn "Docker is required. Install it, then re-run this command:"
  echo "  curl -fsSL https://get.docker.com | sh"
  exit 1
fi

if [ -d "$DIR/.git" ]; then
  say "Updating existing checkout in $DIR ..."
  git -C "$DIR" pull --ff-only || true
else
  say "Downloading Rased into $DIR ..."
  git clone --depth 1 "$REPO" "$DIR"
fi

cd "$DIR"
chmod +x scripts/*.sh 2>/dev/null || true
# Hand off to the installer with all the passed arguments.
exec bash scripts/install-agent.sh "$@"
