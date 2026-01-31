# AI Development Template

A Docker-based Coder template optimized for AI development workflows with code-server (VS Code in the browser).

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

## Customization

### Changing the Base Image

Edit `main.tf` and modify the `image` attribute in the `docker_container` resource:

```hcl
resource "docker_container" "workspace" {
  image = "ubuntu:24.04"  # Change to your preferred image
  # ...
}
```

### Installing Additional Packages

Add installation commands to the `startup_script` in the `coder_agent` resource:

```hcl
resource "coder_agent" "main" {
  startup_script = <<-EOT
    # ... existing setup ...

    # Install additional packages
    sudo apt-get install -y python3 python3-pip nodejs npm
  EOT
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
