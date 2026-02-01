#!/bin/bash
# oh-my-claudecode.sh - Install Oh-My-ClaudeCode plugin
# Requires: Claude Code (from base-ai-tools.sh), Node.js and npm (from common-deps.sh)
set -e

# Install oh-my-claudecode plugin (Claude Code already installed by base-ai-tools.sh)
sudo npm install -g oh-my-claudecode
