#!/bin/bash
# oh-my-opencode.sh - Install Oh-My-OpenCode plugin
# Requires: OpenCode (from base-ai-tools.sh), Node.js and npm (from common-deps.sh)
set -e

# Install oh-my-opencode npm package globally
sudo npm install -g oh-my-opencode

# NOTE: The oh-my-opencode install command runs an interactive wizard
# that cannot be automated. Users should run 'oh-my-opencode install'
# manually after the workspace starts to complete setup.
echo "oh-my-opencode installed. Run 'oh-my-opencode install' to complete setup."
