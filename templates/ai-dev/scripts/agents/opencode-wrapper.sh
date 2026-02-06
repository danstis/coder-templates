#!/bin/bash
# opencode-wrapper.sh - Launch OpenCode with first-run oh-my-opencode setup
# This script checks if oh-my-opencode is configured and runs setup if needed

CONFIG_FILE="$HOME/.config/opencode/oh-my-opencode.json"
ALT_CONFIG_FILE="$HOME/.opencode/oh-my-opencode.json"

# Check if oh-my-opencode config exists
if [ ! -f "$CONFIG_FILE" ] && [ ! -f "$ALT_CONFIG_FILE" ]; then
  # Check if oh-my-opencode is installed
  if command -v oh-my-opencode &> /dev/null; then
    echo "First-time setup: Running oh-my-opencode install..."
    echo "Complete the setup wizard to configure your AI providers."
    echo ""
    oh-my-opencode install
  fi
fi

# Launch opencode
exec opencode
