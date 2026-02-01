#!/bin/bash
# agent-os.sh - Install Agent OS
# Requires: git (from common-deps.sh)
# Provides: Agent OS standards system at /home/coder/agent-os
set -e

AGENT_OS_VERSION="v3.0.0"
AGENT_OS_DIR="/home/coder/agent-os"

# Clone Agent OS at pinned version
if [ ! -d "$AGENT_OS_DIR" ]; then
  sudo -u coder git clone --branch "$AGENT_OS_VERSION" --depth 1 \
    https://github.com/buildermethods/agent-os.git "$AGENT_OS_DIR"
else
  echo "Agent OS already installed at $AGENT_OS_DIR"
fi

# Ensure ownership
sudo chown -R coder:coder "$AGENT_OS_DIR"
