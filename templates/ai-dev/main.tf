terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    coder = {
      source  = "coder/coder"
      version = "~> 0.12"
    }
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "stack" {
  name         = "stack"
  display_name = "Development Stack"
  description  = "Select the development stack to install"
  default      = "python-uv"
  type         = "string"
  mutable      = false

  option {
    name  = "Python (uv)"
    value = "python-uv"
    icon  = "/icon/python.svg"
  }
  option {
    name  = "Python (pip)"
    value = "python-pip"
    icon  = "/icon/python.svg"
  }
  option {
    name  = "Go"
    value = "go"
    icon  = "/icon/go.svg"
  }
  option {
    name  = "Node.js"
    value = "node"
    icon  = "/icon/nodejs.svg"
  }
  option {
    name  = "None"
    value = "none"
    icon  = "/icon/code.svg"
  }
}

data "coder_parameter" "ai_agent" {
  name         = "ai_agent"
  display_name = "AI Agent"
  description  = "Select the AI coding agent to install"
  default      = "oh-my-claudecode"
  type         = "string"
  mutable      = false

  option {
    name  = "Oh-My-ClaudeCode"
    value = "oh-my-claudecode"
    icon  = "/icon/claude.svg"
  }
  option {
    name  = "Claude Code"
    value = "claude"
    icon  = "/icon/claude.svg"
  }
  option {
    name  = "Oh-My-OpenCode"
    value = "oh-my-opencode"
    icon  = "/icon/terminal.svg"
  }
  option {
    name  = "OpenCode"
    value = "opencode"
    icon  = "/icon/terminal.svg"
  }
  option {
    name  = "Relentless"
    value = "relentless"
    icon  = "/icon/terminal.svg"
  }
  option {
    name  = "None"
    value = "none"
    icon  = "/icon/code.svg"
  }
}

locals {
  # Stack installation scripts
  stack_install = lookup({
    "python-uv"  = <<-EOF
      # Install Python with uv
      curl -LsSf https://astral.sh/uv/install.sh | sudo -u coder sh
      echo 'export PATH="$HOME/.local/bin:$PATH"' | sudo -u coder tee -a /home/coder/.bashrc
    EOF
    "python-pip" = <<-EOF
      # Install Python with pip
      sudo apt-get install -y python3 python3-pip python3-venv
    EOF
    "go"         = <<-EOF
      # Install Go
      sudo apt-get install -y golang
    EOF
    "node"       = <<-EOF
      # Install Node.js 24.x
      curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
      sudo apt-get install -y nodejs
    EOF
    "none"       = "echo 'No development stack selected'"
  }, data.coder_parameter.stack.value, "echo 'Unknown stack'")

  # AI agent installation scripts
  ai_agent_install = lookup({
    "claude"           = <<-EOF
      sudo npm install -g @anthropic-ai/claude-code
    EOF
    "opencode"         = <<-EOF
      sudo npm install -g opencode-ai
    EOF
    "oh-my-claudecode" = <<-EOF
      sudo npm install -g @anthropic-ai/claude-code
      # oh-my-claudecode setup script available at /home/coder/install-oh-my-claudecode.sh
    EOF
    "oh-my-opencode"   = <<-EOF
      sudo npm install -g oh-my-opencode
    EOF
    "relentless"       = <<-EOF
      sudo npm install -g @anthropic-ai/claude-code
      sudo npm install -g @arvorco/relentless
    EOF
    "none"             = "echo 'No AI agent selected'"
  }, data.coder_parameter.ai_agent.value, "echo 'Unknown AI agent'")

  # Determine if we need the oh-my-claudecode install script
  include_oh_my_claudecode_script = data.coder_parameter.ai_agent.value == "oh-my-claudecode"
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash

    # Install sudo first (needed for subsequent commands)
    apt-get update && apt-get install -y sudo

    # Create coder user if it doesn't exist
    if ! id -u coder &>/dev/null; then
      sudo useradd -m -s /bin/bash coder
      sudo usermod -aG sudo coder
      echo "coder ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/coder
    fi

    # Install essential packages
    sudo apt-get update
    sudo apt-get install -y curl wget git nodejs npm expect

    # Install selected development stack
    (
      ${local.stack_install}
    ) || echo "Stack installation completed with errors"

    # Install selected AI agent
    (
      ${local.ai_agent_install}
    ) || echo "AI agent installation completed with errors"

    # Create oh-my-claudecode setup script if selected
    %{if local.include_oh_my_claudecode_script}
    cat <<'EOF' > /home/coder/install-oh-my-claudecode.sh
${file("${path.module}/scripts/install-oh-my-claudecode.sh")}
EOF
    chmod +x /home/coder/install-oh-my-claudecode.sh
    chown coder:coder /home/coder/install-oh-my-claudecode.sh
    %{endif}

    # Install code-server
    if ! command -v code-server &>/dev/null; then
      curl -fsSL https://code-server.dev/install.sh | sh
    fi

    # Start code-server as coder user
    sudo -u coder code-server --bind-addr 0.0.0.0:13337 --auth none /home/coder &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk_usage"
    script       = "coder stat disk --path /home/coder"
    interval     = 10
    timeout      = 1
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = "ubuntu:24.04"
  name  = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"

  hostname = data.coder_workspace.me.name

  # Install curl first (required for agent init script), then run Coder agent
  command = ["sh", "-c", "apt-get update && apt-get install -y curl && ${coder_agent.main.init_script}"]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
  }

  network_mode = "host"
}

resource "coder_app" "code_server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Web"
  url          = "http://localhost:13337?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

# Claude Code app - shown for claude and oh-my-claudecode options
resource "coder_app" "claude_code" {
  count        = contains(["claude", "oh-my-claudecode"], data.coder_parameter.ai_agent.value) ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "claude-code"
  display_name = "Claude Code"
  icon         = "/icon/claude.svg"
  command      = "cd /home/coder && claude"
}

# OpenCode app - shown for opencode and oh-my-opencode options
resource "coder_app" "opencode" {
  count        = contains(["opencode", "oh-my-opencode"], data.coder_parameter.ai_agent.value) ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "opencode"
  display_name = "OpenCode"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && opencode"
}

# Relentless app - shown for relentless option
resource "coder_app" "relentless" {
  count        = data.coder_parameter.ai_agent.value == "relentless" ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "relentless"
  display_name = "Relentless"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && relentless"
}
