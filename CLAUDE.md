# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains Coder templates for creating development workspace environments. Templates are written in Terraform and use the Coder and Docker providers to provision containerized development environments with pre-configured tooling.

## Architecture Overview

### Template Structure

Each template lives in `templates/<template-name>/` with a `main.tf` file as the entry point. The current template is `ai-dev`, which provisions Docker-based development workspaces.

### Terraform Provider Dependencies

Templates use two key providers:
- **coder/coder** (~> 0.12): Provides workspace metadata, parameters, agent configuration, and app resources
- **kreuzwerker/docker** (~> 3.0): Manages Docker containers and volumes

### Key Terraform Resources Pattern

The `ai-dev` template follows this resource hierarchy:

1. **Data Sources**: `coder_workspace`, `coder_workspace_owner` provide workspace context
2. **Parameters**: `coder_parameter` resources define user-selectable options (stack, AI agent)
3. **Locals**: Dynamic script generation based on parameters using `lookup()` maps
4. **Volume**: `docker_volume` for persistent `/home/coder` storage
5. **Agent**: `coder_agent` with startup_script containing initialization logic
6. **Container**: `docker_container` that runs the agent init script
7. **Apps**: `coder_app` resources exposing web services (code-server)

### Dynamic Installation Pattern

The template uses a parameterized installation pattern:

```hcl
data "coder_parameter" "stack" {
  # User selects from python-uv, python-pip, go, node, none
}

locals {
  stack_install = lookup({
    "python-uv" = "# install script..."
    # ... other options
  }, data.coder_parameter.stack.value, "default")
}
```

This pattern is used for both development stacks and AI agents.

## Development Commands

### Template Development

```bash
# Initialize Terraform (from template directory)
cd templates/ai-dev
terraform init

# Validate template syntax
terraform validate

# Plan (requires Coder server connection)
terraform plan

# Apply (creates/updates workspace - requires Coder server)
terraform apply
```

### Testing Templates

Templates must be tested with a running Coder deployment. There is no local-only test mode since templates interact with Coder server APIs.

```bash
# Push template to Coder server for testing
coder templates push ai-dev -d templates/ai-dev
```

## Configuration Patterns

### Startup Script Architecture

The `coder_agent.startup_script` executes in the container on startup. Critical ordering:

1. Install `sudo` first (required for user creation)
2. Create `coder` user with passwordless sudo
3. Install essential packages (`curl`, `wget`, `git`)
4. Install selected stack (wrapped in subshell with `|| echo` for non-fatal errors)
5. Install selected AI agent (wrapped in subshell with `|| echo` for non-fatal errors)
6. Install code-server if not present
7. Start code-server in background on port 13337

### Network Configuration

Uses `network_mode = "host"` for simplicity. The container directly accesses the host's network, making services like code-server accessible without port mapping.

### Git Configuration

Git author/committer info is automatically set via agent environment variables using workspace owner data:

```hcl
env = {
  GIT_AUTHOR_NAME = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  # ...
}
```

### Resource Naming

Container and volume names follow the pattern: `coder-{owner}-{workspace}` for containers, `coder-{workspace_id}-home` for volumes.

## Supported Stacks and Agents

### Development Stacks
- **python-uv**: Python with uv package manager (default)
- **python-pip**: Python with pip
- **go**: Go language
- **node**: Node.js 24.x
- **none**: No stack installed

### AI Agents
- **claude**: Claude Code (@anthropic-ai/claude-code)
- **opencode**: OpenCode (opencode-ai)
- **oh-my-opencode**: Oh-My-OpenCode
- **oh-my-claudecode**: Oh-My-ClaudeCode (default)
- **relentless**: Relentless (@arvorco/relentless)
- **none**: No AI agent

All AI agents require Node.js and are installed globally via npm.

## Important Constraints

### Parameter Mutability

Template parameters use `mutable = false`, meaning they can only be set during workspace creation, not changed after deployment. This prevents runtime configuration drift.

### Container Count Pattern

```hcl
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  # ...
}
```

The `count` ensures containers are only created when the workspace is started (not stopped/deleted).

### Code-Server Port

Hardcoded to port 13337 in both startup script and `coder_app` URL. Must be changed in both locations if modified.

## Monitoring

The agent includes three metadata collectors that report to the Coder dashboard:
- CPU usage (`coder stat cpu`)
- RAM usage (`coder stat mem`)
- Disk usage (`coder stat disk --path /home/coder`)

All run every 10 seconds with 1-second timeout.
