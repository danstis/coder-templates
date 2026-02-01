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
    name  = "None"
    value = "none"
    icon  = "/icon/code.svg"
  }
}

data "coder_parameter" "ai_plugin" {
  name         = "ai_plugin"
  display_name = "AI Agent Plugin"
  description  = "Select optional AI agent plugin (oh-my-* tools that enhance base CLI tools)"
  default      = "none"
  type         = "string"
  mutable      = false

  option {
    name  = "None"
    value = "none"
    icon  = "/icon/code.svg"
  }
  option {
    name  = "Oh-My-ClaudeCode"
    value = "oh-my-claudecode"
    icon  = "/icon/claude.svg"
  }
  option {
    name  = "Oh-My-OpenCode"
    value = "oh-my-opencode"
    icon  = "/icon/terminal.svg"
  }
}

locals {
  # Stack installation scripts from files (node removed - now in common-deps.sh)
  stack_install = lookup({
    "python-uv"  = file("${path.module}/scripts/stacks/python-uv.sh")
    "python-pip" = file("${path.module}/scripts/stacks/python-pip.sh")
    "go"         = file("${path.module}/scripts/stacks/go.sh")
    "none"       = "echo 'No development stack selected'"
  }, data.coder_parameter.stack.value, "echo 'Unknown stack'")

  # Plugin installation scripts (renamed from ai_agent_install)
  ai_plugin_install = lookup({
    "oh-my-claudecode" = file("${path.module}/scripts/agents/oh-my-claudecode.sh")
    "oh-my-opencode"   = file("${path.module}/scripts/agents/oh-my-opencode.sh")
    "none"             = "echo 'No AI plugin selected'"
  }, data.coder_parameter.ai_plugin.value, "echo 'Unknown AI plugin'")

  # Common dependencies script
  common_deps = file("${path.module}/scripts/common-deps.sh")

  # Base AI tools script
  base_ai_tools = file("${path.module}/scripts/base-ai-tools.sh")

  # Determine if we need the oh-my-claudecode install script
  include_oh_my_claudecode_script = data.coder_parameter.ai_plugin.value == "oh-my-claudecode"
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Run common dependencies installation (now includes Node 24 + gh CLI)
    ${local.common_deps}

    # Install all base AI CLI tools
    (
      ${local.base_ai_tools}
    ) || echo "Base AI tools installation completed with errors"

    # Install selected development stack
    (
      ${local.stack_install}
    ) || echo "Stack installation completed with errors"

    # Install selected AI plugin
    (
      ${local.ai_plugin_install}
    ) || echo "AI plugin installation completed with errors"

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
    sudo -u coder code-server --bind-addr 0.0.0.0:13337 --auth none /home/coder >/tmp/code-server.log 2>&1 &
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

# Claude Code app - always available (base AI tool)
resource "coder_app" "claude_code" {
  agent_id     = coder_agent.main.id
  slug         = "claude-code"
  display_name = "Claude Code"
  icon         = "/icon/claude.svg"
  command      = "cd /home/coder && claude"
}

# OpenCode app - always available (base AI tool)
resource "coder_app" "opencode" {
  agent_id     = coder_agent.main.id
  slug         = "opencode"
  display_name = "OpenCode"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && opencode"
}

# Relentless app - always available (base AI tool)
resource "coder_app" "relentless" {
  agent_id     = coder_agent.main.id
  slug         = "relentless"
  display_name = "Relentless"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && relentless"
}

# Codex app - always available (base AI tool)
resource "coder_app" "codex" {
  agent_id     = coder_agent.main.id
  slug         = "codex"
  display_name = "OpenAI Codex"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && codex"
}

# Copilot app - always available (base AI tool)
resource "coder_app" "copilot" {
  agent_id     = coder_agent.main.id
  slug         = "copilot"
  display_name = "GitHub Copilot"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && copilot"
}

# Gemini app - always available (base AI tool)
resource "coder_app" "gemini" {
  agent_id     = coder_agent.main.id
  slug         = "gemini"
  display_name = "Google Gemini"
  icon         = "/icon/terminal.svg"
  command      = "cd /home/coder && gemini"
}
