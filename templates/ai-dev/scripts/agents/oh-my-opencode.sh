#!/bin/bash
# oh-my-opencode.sh - Install Oh-My-OpenCode plugin
# Requires: OpenCode (from base-ai-tools.sh), Node.js and npm (from common-deps.sh)
set -e

# Install oh-my-opencode plugin (OpenCode already installed by base-ai-tools.sh)
sudo npm install -g oh-my-opencode
