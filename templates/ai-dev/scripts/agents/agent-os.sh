#!/bin/bash
# agent-os.sh - Install Agent OS
# Requires: git (from common-deps.sh)
# Provides: Agent OS standards system at /home/coder/agent-os
set -e

AGENT_OS_VERSION="v3.0.0"
AGENT_OS_DIR="/home/coder/agent-os"

# Guard against symlink attacks: if the path exists as a symlink, remove it
# to prevent chown -R from following the link outside /home/coder.
if [ -L "$AGENT_OS_DIR" ]; then
  echo "WARNING: $AGENT_OS_DIR is a symlink — removing to prevent unsafe chown traversal"
  rm -f "$AGENT_OS_DIR"
fi

# Clone Agent OS at pinned version
if [ ! -d "$AGENT_OS_DIR" ]; then
  sudo -u coder git clone --branch "$AGENT_OS_VERSION" --depth 1 \
    https://github.com/buildermethods/agent-os.git "$AGENT_OS_DIR"
else
  echo "Agent OS already installed at $AGENT_OS_DIR"
fi

# Verify the resolved path is under /home/coder before changing ownership
RESOLVED_DIR="$(readlink -f "$AGENT_OS_DIR")"
case "$RESOLVED_DIR" in
  /home/coder/*)
    sudo chown -R coder:coder "$AGENT_OS_DIR"
    ;;
  *)
    echo "ERROR: $AGENT_OS_DIR resolves to $RESOLVED_DIR which is outside /home/coder — skipping chown"
    exit 1
    ;;
esac
