# AI Development Template

A Docker-based Coder template optimized for AI development workflows with code-server (VS Code in the browser).

## Template Metadata

When importing this template into Coder, use the following recommended metadata:

| Property | Value |
|----------|-------|
| **Name** | `ai-dev` |
| **Display Name** | AI Development |
| **Description** | Docker-based development environment with AI coding agents, multiple language stacks, and VS Code Web |
| **Icon** | `/icon/code.svg` |

### CLI Import

```bash
# Create the template with metadata
coder templates push ai-dev \
  --directory templates/ai-dev

# Set display name, description, and icon after creation
coder templates edit ai-dev \
  --display-name "AI Development" \
  --description "Docker-based development environment with AI coding agents, multiple language stacks, and VS Code Web" \
  --icon "/icon/code.svg"
```

### Web UI Import

When creating the template through the Coder dashboard:
1. Click "Create Template" → "From scratch"
2. Upload or paste the template files
3. Set the name to `ai-dev`
4. Set the display name to "AI Development"
5. Set the description to "Docker-based development environment with AI coding agents, multiple language stacks, and VS Code Web"
6. Select an appropriate icon (e.g., Code icon)

## Overview

This template provides a complete development environment running in a Docker container with:
- Ubuntu 24.04 LTS base image
- code-server (VS Code Web) for browser-based development
- Persistent home directory storage
- Pre-configured development tools

## Features

- **Web-based IDE**: Access VS Code through your browser via code-server
- **Local VS Code Support**: Connect your local VS Code to the workspace via Coder CLI and Remote-SSH
- **Persistent Storage**: Your home directory (`/home/coder`) persists across workspace rebuilds
- **Essential Tools**: Pre-installed curl, wget, git, Node.js, and npm
- **AI Tools**: Pre-installed Claude Code CLI and oh-my-claudecode setup script
- **Git Pre-configuration**: Git author and committer information automatically set from your Coder profile
- **System Metrics**: Real-time CPU, RAM, and disk usage monitoring in the Coder dashboard
- **No Authentication**: code-server runs with `--auth none` for seamless access
- **Host Network Mode**: Direct network access for easy service development

## Requirements

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [Coder](https://coder.com/docs/v2/latest/install) server deployed
- Sufficient disk space for Docker volumes

## Usage

### Creating a Workspace

1. Navigate to your Coder deployment
2. Click "Create Workspace"
3. Select the "ai-dev" template
4. Provide a workspace name
5. Click "Create Workspace"

### Accessing the IDE

#### Browser-based (code-server)

Once your workspace is running, click on the "VS Code Web" app in the Coder dashboard. This will open code-server in a new browser tab with your workspace ready to use.

#### Local VS Code Connection

You can connect your local VS Code installation to your workspace for a native development experience:

1. **Install Coder CLI**:
   ```bash
   # macOS/Linux
   curl -fsSL https://coder.com/install.sh | sh

   # Windows (PowerShell)
   irm https://coder.com/install.ps1 | iex
   ```

2. **Login to Coder**:
   ```bash
   coder login https://your-coder-url.com
   ```

3. **Configure SSH**:
   ```bash
   coder config-ssh
   ```
   This adds your Coder workspaces to your SSH config (`~/.ssh/config`).

4. **Install Remote-SSH Extension**:
   - Open VS Code
   - Install the "Remote - SSH" extension (ms-vscode-remote.remote-ssh)

5. **Connect to Workspace**:
   - Press `F1` or `Ctrl+Shift+P` (Windows/Linux) / `Cmd+Shift+P` (macOS)
   - Type "Remote-SSH: Connect to Host"
   - Select your workspace from the list (format: `coder.<workspace-name>`)
   - VS Code will open a new window connected to your workspace

### Workspace Directory

Your persistent home directory is mounted at `/home/coder`. All files and configurations stored here will persist across workspace restarts and rebuilds.

### Using Claude Code and oh-my-claudecode

This template comes with [Claude Code](https://docs.anthropic.com/claude/docs/claude-code) installed. To set up the [oh-my-claudecode](https://yeachan-heo.github.io/oh-my-claudecode-website/) plugin:

1.  Open a terminal in your workspace.
2.  Login to Claude:
    ```bash
    claude login
    ```
3.  Run the installation script:
    ```bash
    ./install-oh-my-claudecode.sh
    ```
    This script automates the plugin installation commands.

### Using Agent OS

If you selected the **Agent OS** plugin during workspace creation, [Agent OS](https://buildermethods.com/agent-os) is installed at `/home/coder/agent-os`.

Agent OS provides a lightweight standards system that helps keep AI agents aligned with your project's conventions, patterns, and architectural decisions.

#### Verification

Confirm Agent OS is installed:

```bash
ls /home/coder/agent-os
```

You should see the Agent OS directory containing `commands/`, `profiles/`, `scripts/`, and `config.yml`.

#### Quick Start

1. Navigate to your project directory:
   ```bash
   cd /home/coder/my-project
   ```

2. Install Agent OS into your project:
   ```bash
   /home/coder/agent-os/scripts/project-install.sh
   ```
   This creates an `agent-os/` directory in your project with standards and Claude Code slash commands.

3. Use the slash commands in Claude Code:
   - `/discover-standards` - Extract patterns from your codebase
   - `/inject-standards` - Deploy standards into your context
   - `/shape-spec` - Create better specs for AI-assisted builds

#### Customization

Agent OS uses profiles to organize standards. The default profile is installed at `/home/coder/agent-os/profiles/default/`. You can:

- Edit standards in `profiles/default/global/` to match your conventions
- Create new profiles for different project types
- Configure profile inheritance in `config.yml`

See the [Agent OS documentation](https://buildermethods.com/agent-os) for more details.

## Template Architecture

### Scripts Directory Structure

The template includes modular installation scripts organized by category:

```
scripts/
├── common-deps.sh          # Shared dependencies (sudo, git, curl, wget, nodejs, npm)
├── install-oh-my-claudecode.sh
├── stacks/                 # Development stack installers
│   ├── python-uv.sh        # Python with uv package manager
│   ├── python-pip.sh       # Python with pip
│   ├── go.sh               # Go language
│   └── node.sh             # Node.js 24.x
└── agents/                 # AI agent installers
    ├── oh-my-claudecode.sh # Oh-My-ClaudeCode
    ├── oh-my-opencode.sh   # Oh-My-OpenCode
    └── agent-os.sh         # Agent OS
```

### How Scripts Are Used

The `main.tf` file uses Terraform's `file()` function to load these scripts dynamically based on workspace parameters:

1. **common-deps.sh** is always executed first to install shared dependencies
2. **Stack scripts** are selected based on the `stack` parameter (python-uv, python-pip, go, node, or none)
3. **Agent scripts** are selected based on the `ai_plugin` parameter (oh-my-claudecode, oh-my-opencode, agent-os, or none)

This modular approach allows:
- Easy addition of new stacks or agents by creating new scripts
- Clear separation of concerns
- Reusable components for other templates
- Simplified main.tf configuration

## Customization

### Adding a New Development Stack

1. Create a new script in `scripts/stacks/your-stack.sh`:
   ```bash
   #!/bin/bash
   # your-stack.sh - Install Your Stack
   # Requires: apt (from common-deps.sh)
   set -e

   sudo apt-get install -y your-stack-package
   ```

2. Add to the `data "coder_parameter" "stack"` options in `main.tf`:
   ```hcl
   option {
     name  = "Your Stack"
     value = "your-stack"
     icon  = "/icon/your-icon.svg"
   }
   ```

3. Add to the `stack_install` lookup in the locals block:
   ```hcl
   "your-stack" = file("${path.module}/scripts/stacks/your-stack.sh")
   ```

### Adding a New AI Agent

1. Create a new script in `scripts/agents/your-agent.sh`:
   ```bash
   #!/bin/bash
   # your-agent.sh - Install Your Agent
   # Requires: Node.js and npm (from common-deps.sh)
   set -e

   sudo npm install -g your-agent-package
   ```

2. Add to the `data "coder_parameter" "ai_plugin"` options in `main.tf`
3. Add to the `ai_plugin_install` lookup in the locals block

### Changing the Base Image

Edit `main.tf` and modify the `image` attribute in the `docker_container` resource:

```hcl
resource "docker_container" "workspace" {
  image = "ubuntu:24.04"  # Change to your preferred image
  # ...
}
```

### Changing code-server Port

Modify the port in both the startup script and the app URL:

```hcl
# In coder_agent startup_script
code-server --bind-addr 0.0.0.0:8080 --auth none /home/coder &

# In coder_app resource
resource "coder_app" "code_server" {
  url = "http://localhost:8080?folder=/home/coder"
  # ...
}
```

### Adding Authentication

To enable code-server authentication, remove `--auth none` and set a password:

```bash
code-server --bind-addr 0.0.0.0:13337 /home/coder &
```

Then access the password from `~/.config/code-server/config.yaml` in the container.

## Network Configuration

This template uses `network_mode = "host"` for simplicity, allowing the container to access the host's network directly. For production use, consider using a dedicated Docker network for better isolation.

## Troubleshooting

### code-server won't start

Check the agent logs in the Coder dashboard for installation errors. Ensure Docker has internet access to download code-server.

### Volume permissions issues

The startup script creates a `coder` user with sudo privileges. If you encounter permission issues, verify the user exists:

```bash
id coder
```

### Container won't start

Check Docker logs:

```bash
docker logs coder-<username>-<workspace-name>
```

### Local VS Code Connection Issues

#### Agent not connecting

Verify the Coder agent is running:
```bash
coder list
```

Your workspace should show as "Running". If not, start it from the Coder dashboard.

#### SSH connection fails

Check the agent logs in the Coder dashboard (Workspace → Logs) for connection errors. Common issues:
- Firewall blocking SSH connections
- Coder CLI not logged in (`coder login` again)
- SSH config not updated (run `coder config-ssh` again)

#### Workspace not appearing in Remote-SSH

Ensure `coder config-ssh` completed successfully. Check your SSH config:
```bash
cat ~/.ssh/config | grep coder
```

You should see entries for your Coder workspaces. If missing, run `coder config-ssh` again.

## Contributing

To contribute improvements to this template:

1. Fork the repository
2. Make your changes
3. Test thoroughly with a Coder deployment
4. Submit a pull request

## License

This template is provided as-is for use with Coder deployments.
