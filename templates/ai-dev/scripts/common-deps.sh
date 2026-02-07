#!/bin/bash
# common-deps.sh - Install shared dependencies for all workspace configurations
# This script runs during agent startup.
set -e

# Ensure we have sudo access (bootstrap should have installed it)
if ! command -v sudo &> /dev/null; then
  echo "Error: sudo is required but not installed."
  exit 1
fi

# Create coder user if it doesn't exist (idempotent)
if ! id -u coder &>/dev/null; then
  sudo useradd -m -s /bin/bash coder
  sudo usermod -aG sudo coder
  echo "coder ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/coder
fi

# Ensure home directory is owned by coder user
# Use sudo to ensure we have permissions to chown if needed
sudo chown -R coder:coder /home/coder

# Install essential packages (nodejs/npm excluded - installed via nodesource below)
sudo apt-get update
sudo apt-get install -y curl wget git expect unzip

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
# The official installer uses BUN_INSTALL to determine the install directory.
# Non-fatal on failure to avoid breaking workspace startup.
if ! command -v bun >/dev/null 2>&1; then
  echo "Installing Bun..."
  # Ensure unzip is available (last-ditch effort)
  if ! command -v unzip >/dev/null 2>&1; then
    apt-get update && apt-get install -y unzip
  fi

  # Run installer with BUN_INSTALL set to /usr/local
  # This avoids the 404 error caused by incorrect flag usage
  curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash || true

  # Ensure it's symlinked to /usr/bin for scripts using #!/usr/bin/env bun
  if [ -x /usr/local/bin/bun ] && [ ! -x /usr/bin/bun ]; then
    ln -sf /usr/local/bin/bun /usr/bin/bun || true
  fi
fi

# Final check: if bun still isn't available, print a warning (non-fatal)
if ! command -v bun >/dev/null 2>&1; then
  echo "⚠ bun not found after install attempts - relentless may fail until bun is available"
fi

# Install code-server
# We install it here to avoid apt lock conflicts with other startup scripts.
# The startup logic remains in the coder_button/script to ensure volume visibility.
if ! command -v code-server >/dev/null 2>&1; then
  echo "Installing code-server..."
  curl -fsSL https://code-server.dev/install.sh | sh
fi
