#!/bin/bash
# oh-my-claudecode.sh - Install Oh-My-ClaudeCode plugin
# Requires: Claude Code (from base-ai-tools.sh)
set -e

# Install oh-my-claudecode plugin via Claude Code's plugin system
# This uses the undocumented CLI commands for non-interactive installation
# Reference: https://github.com/Yeachan-Heo/oh-my-claudecode

# Add the oh-my-claudecode marketplace (idempotent - updates if already present)
sudo -u coder claude mpa https://github.com/Yeachan-Heo/oh-my-claudecode || echo "Failed to add oh-my-claudecode marketplace (non-fatal)"

# Install the plugin from the marketplace
sudo -u coder claude pla oh-my-claudecode || echo "Failed to install oh-my-claudecode plugin (non-fatal)"

echo "oh-my-claudecode plugin installed - run /oh-my-claudecode:omc-setup in Claude Code to complete setup"
