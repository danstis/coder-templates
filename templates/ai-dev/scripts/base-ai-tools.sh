#!/bin/bash
# base-ai-tools.sh - Install all base AI CLI tools
# Requires: Node.js 24 and npm (from common-deps.sh)
# NOTE: set -e is NOT used - each install is independently error-handled

echo "Installing base AI CLI tools..."

# Each tool installed independently with parallel execution for speed
# Background jobs allow parallel installation, reducing total time

sudo npm install -g @anthropic-ai/claude-code &
CLAUDE_PID=$!

sudo npm install -g opencode-ai &
OPENCODE_PID=$!

sudo npm install -g @arvorco/relentless &
RELENTLESS_PID=$!

sudo npm install -g @openai/codex &
CODEX_PID=$!

sudo npm install -g @github/copilot &
COPILOT_PID=$!

sudo npm install -g @google/gemini-cli &
GEMINI_PID=$!

# Wait for all installations and capture exit codes
wait $CLAUDE_PID && echo "✓ Claude Code installed" || echo "⚠ Claude Code installation failed (non-fatal)"
wait $OPENCODE_PID && echo "✓ OpenCode installed" || echo "⚠ OpenCode installation failed (non-fatal)"
wait $RELENTLESS_PID && echo "✓ Relentless installed" || echo "⚠ Relentless installation failed (non-fatal)"
wait $CODEX_PID && echo "✓ Codex installed" || echo "⚠ Codex installation failed (non-fatal)"
wait $COPILOT_PID && echo "✓ Copilot installed" || echo "⚠ Copilot installation failed (non-fatal)"
wait $GEMINI_PID && echo "✓ Gemini installed" || echo "⚠ Gemini installation failed (non-fatal)"

echo "Base AI CLI tools installation complete"
