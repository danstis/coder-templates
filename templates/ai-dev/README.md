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
- **Persistent Storage**: Your home directory (`/home/coder`) persists across workspace rebuilds
- **Essential Tools**: Pre-installed curl, wget, and git
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

Once your workspace is running, click on the "VS Code Web" app in the Coder dashboard. This will open code-server in a new browser tab with your workspace ready to use.

### Workspace Directory

Your persistent home directory is mounted at `/home/coder`. All files and configurations stored here will persist across workspace restarts and rebuilds.

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

## Contributing

To contribute improvements to this template:

1. Fork the repository
2. Make your changes
3. Test thoroughly with a Coder deployment
4. Submit a pull request

## License

This template is provided as-is for use with Coder deployments.
