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

# Install essential packages (nodejs/npm excluded - installed via nodesource below)
apt-get install -y curl wget git expect

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh

# Node.js 24.x (provides nodejs and npm)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
