#!/usr/bin/env bash
# Rased — ONE-COMMAND agent bootstrap. Installs prerequisites (git + Docker) if
# missing, downloads Rased from GitHub, and starts the agent on a new Linux box:
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

# Run privileged steps with sudo when not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    warn "Please run as root, or install sudo first."
    exit 1
  fi
fi

pkg_install() {  # install package(s) with whatever manager exists
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq "$@"
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y "$@"
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y "$@"
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache "$@"
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -Sy --noconfirm "$@"
  else
    return 1
  fi
}

# 1) Prerequisites -----------------------------------------------------------
command -v curl >/dev/null 2>&1 || pkg_install curl || true

if ! command -v git >/dev/null 2>&1; then
  say "Installing git ..."
  pkg_install git || { warn "Could not auto-install git. Install it and re-run."; exit 1; }
fi

if ! command -v docker >/dev/null 2>&1; then
  say "Installing Docker (get.docker.com) ..."
  curl -fsSL https://get.docker.com | $SUDO sh
fi
# Make sure the daemon is running (no-op on non-systemd hosts).
$SUDO systemctl enable --now docker >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  warn "Docker is present but the 'docker compose' plugin is missing. Install docker-compose-plugin and re-run."
  exit 1
fi

# 2) Get the code ------------------------------------------------------------
if [ -d "$DIR/.git" ]; then
  say "Updating existing checkout in $DIR ..."
  git -C "$DIR" pull --ff-only || true
else
  say "Downloading Rased into $DIR ..."
  git clone --depth 1 "$REPO" "$DIR"
fi

# 3) Run the installer with all passed arguments -----------------------------
cd "$DIR"
chmod +x scripts/*.sh 2>/dev/null || true
exec bash scripts/install-agent.sh "$@"
