#!/bin/bash
# node.sh - Install Node.js 24.x (replaces system nodejs from common-deps)
# Requires: curl (from common-deps.sh)
set -e

curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
