#!/bin/bash
# fix-persistent-mount-permissions.sh - Fix ownership on per-user persistent volumes
# Requires: sudo (from coder user NOPASSWD setup)
# Runs as coder user inside startup_script
#
# Docker volumes are created with root ownership by default.
# This script ensures per-user persistent mount points are owned by the coder user.

# Fix ownership on any active persistent mounts
for dir in /home/coder/.vscode-server /home/coder/.config /home/coder/.ssh \
           /home/coder/github.com /home/coder/dev.azure.com \
           /home/coder/.claude /home/coder/.config/opencode; do
  if mountpoint -q "$dir" 2>/dev/null; then
    sudo chown coder:coder "$dir"
  fi
done

# Fix SSH permissions specifically
if mountpoint -q /home/coder/.ssh 2>/dev/null; then
  sudo chmod 700 /home/coder/.ssh
  # Fix permissions on existing SSH files if present
  sudo find /home/coder/.ssh -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
  sudo find /home/coder/.ssh -type f -name "*.pub" -exec chmod 644 {} \;
  [ -f /home/coder/.ssh/config ] && sudo chmod 600 /home/coder/.ssh/config
  [ -f /home/coder/.ssh/known_hosts ] && sudo chmod 644 /home/coder/.ssh/known_hosts
fi
