#!/bin/bash
# common-deps.sh - Install shared dependencies for all workspace configurations
# This script runs as root inside the Docker container during agent startup.
set -e

# Install sudo (needed for user management)
apt-get update && apt-get install -y sudo

# Create coder user if it doesn't exist
if ! id -u coder &>/dev/null; then
  useradd -m -s /bin/bash coder
  usermod -aG sudo coder
  echo "coder ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/coder
fi

# Ensure home directory is owned by coder user (fix for Docker volume permissions)
chown -R coder:coder /home/coder

# Install essential packages (nodejs/npm excluded - installed via nodesource below)
# We do this twice to be absolutely sure unzip is available for the bun installer
apt-get install -y curl wget git expect unzip
unzip -v >/dev/null 2>&1 || (apt-get update && apt-get install -y unzip)

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh

# Node.js 24.x (provides nodejs and npm)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Bun (fast JavaScript runtime) and make it available system-wide.
# The official installer defaults to a user directory; request /usr/local so
# the `bun` binary is on PATH for all users. Fall back to copying from the
# installer location if necessary. Non-fatal on failure to avoid breaking
# workspace startup when network issues occur.
if ! command -v unzip >/dev/null 2>&1; then
  echo "Installing missing unzip for bun..."
  apt-get update && apt-get install -y unzip
fi
curl -fsSL https://bun.sh/install | bash -s -- --bun-dir /usr/local || true
if ! command -v bun >/dev/null 2>&1; then
  # Try common installer locations and create system-wide symlinks so
  # scripts using `#!/usr/bin/env bun` reliably find the binary.
  for candidate in /usr/local/bin/bun /root/.bun/bin/bun /home/coder/.bun/bin/bun; do
    if [ -x "$candidate" ]; then
      ln -sf "$candidate" /usr/local/bin/bun || true
      ln -sf "$candidate" /usr/bin/bun || true
      chmod +x /usr/local/bin/bun /usr/bin/bun 2>/dev/null || true
      break
    fi
  done
fi

# Final check: if bun still isn't available, print a warning (non-fatal)
if ! command -v bun >/dev/null 2>&1; then
  echo "⚠ bun not found after install attempts - relentless may fail until bun is available"
fi
