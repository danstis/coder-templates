#!/bin/bash
# relentless.sh - Install Relentless
# Requires: Node.js and npm (from common-deps.sh)
set -e

sudo npm install -g @anthropic-ai/claude-code
sudo npm install -g @arvorco/relentless
