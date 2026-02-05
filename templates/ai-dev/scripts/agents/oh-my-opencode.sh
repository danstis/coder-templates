#!/bin/bash
# oh-my-opencode.sh - Install Oh-My-OpenCode plugin
# Requires: OpenCode (from base-ai-tools.sh), Node.js and npm (from common-deps.sh)
set -e

# Install oh-my-opencode npm package globally
sudo npm install -g oh-my-opencode

# Run the oh-my-opencode install command as coder user
# This sets up the plugin configuration in ~/.config/opencode/
# Users will need to authenticate with their providers after workspace starts
sudo -u coder oh-my-opencode install --yes 2>/dev/null || sudo -u coder oh-my-opencode install || echo "oh-my-opencode install completed (manual auth required)"
