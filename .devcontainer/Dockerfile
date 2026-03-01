# =============================================================================
# ai-devcontainer-base
# Base Dev Container image with AI/agent CLI tooling preinstalled.
# =============================================================================
FROM mcr.microsoft.com/devcontainers/base:noble

# Set the SHELL option -o pipefail before RUN with a pipe in it (DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Node.js (LTS) via NodeSource
# ---------------------------------------------------------------------------
ARG NODE_VERSION=22
# hadolint ignore=DL3008
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# GitHub CLI
# ---------------------------------------------------------------------------
# hadolint ignore=DL3008
RUN mkdir -p /etc/apt/keyrings \
    && chmod 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# AI / Agent CLI tools (npm global installs)
# ---------------------------------------------------------------------------
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.42
# renovate: datasource=npm depName=@github/copilot
ARG GITHUB_COPILOT_VERSION=0.0.410
# renovate: datasource=npm depName=@google/gemini-cli
ARG GEMINI_CLI_VERSION=0.28.2
# renovate: datasource=npm depName=@openai/codex
ARG OPENAI_CODEX_VERSION=0.101.0

RUN npm install -g \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @github/copilot@${GITHUB_COPILOT_VERSION} \
    @google/gemini-cli@${GEMINI_CLI_VERSION} \
    @openai/codex@${OPENAI_CODEX_VERSION} \
    && npm cache clean --force

# ---------------------------------------------------------------------------
# OpenCode CLI
# ---------------------------------------------------------------------------
RUN curl -fsSL https://opencode.ai/install | bash \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && rm -rf /root/.opencode

# ---------------------------------------------------------------------------
# Amp CLI
# ---------------------------------------------------------------------------
RUN curl -fsSL https://ampcode.com/install.sh | bash \
    && mv /root/.amp/bin/amp /usr/local/bin/amp \
    && rm -rf /root/.amp

# ---------------------------------------------------------------------------
# Verification labels
# ---------------------------------------------------------------------------
LABEL maintainer="danstis" \
    description="Dev Container base image with AI/agent CLI tooling" \
    org.opencontainers.image.source="https://github.com/danstis/ai-devcontainer-base"
