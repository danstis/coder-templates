#!/bin/bash
# python-uv.sh - Install Python with uv package manager
# Requires: curl (from common-deps.sh)
set -e

curl -LsSf https://astral.sh/uv/install.sh | sudo -u coder sh
echo 'export PATH="$HOME/.local/bin:$PATH"' | sudo -u coder tee -a /home/coder/.bashrc
