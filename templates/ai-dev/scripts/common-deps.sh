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

# Install essential packages
apt-get install -y curl wget git nodejs npm expect
