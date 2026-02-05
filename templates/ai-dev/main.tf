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

# --- Development Stacks (order 1-3) ---
data "coder_parameter" "stack_python_uv" {
  name         = "stack_python_uv"
  display_name = "Python (uv)"
  description  = "Install Python with uv package manager"
  icon         = "/icon/python.svg"
  type         = "bool"
  default      = "true"
  mutable      = false
  order        = 1
}

data "coder_parameter" "stack_python_pip" {
  name         = "stack_python_pip"
  display_name = "Python (pip)"
  description  = "Install Python with pip and venv"
  icon         = "/icon/python.svg"
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 2
}

data "coder_parameter" "stack_go" {
  name         = "stack_go"
  display_name = "Go"
  description  = "Install the Go programming language"
  icon         = "/icon/go.svg"
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 3
}

# --- AI Plugins (order 4-5) ---
data "coder_parameter" "plugin_oh_my_claudecode" {
  name         = "plugin_oh_my_claudecode"
  display_name = "Oh-My-ClaudeCode"
  description  = "Install Oh-My-ClaudeCode plugin for Claude Code"
  icon         = "/icon/claude.svg"
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 4
}

data "coder_parameter" "plugin_oh_my_opencode" {
  name         = "plugin_oh_my_opencode"
  display_name = "Oh-My-OpenCode"
  description  = "Install Oh-My-OpenCode plugin for OpenCode"
  icon         = "/icon/opencode.svg"
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 5
}

locals {
  # Stack installation scripts - concatenate all selected stacks
  stack_install = join("\n", compact([
    data.coder_parameter.stack_python_uv.value == "true" ? file("${path.module}/scripts/stacks/python-uv.sh") : "",
    data.coder_parameter.stack_python_pip.value == "true" ? file("${path.module}/scripts/stacks/python-pip.sh") : "",
    data.coder_parameter.stack_go.value == "true" ? file("${path.module}/scripts/stacks/go.sh") : "",
  ]))

  # Plugin installation scripts - concatenate all selected plugins
  ai_plugin_install = join("\n", compact([
    data.coder_parameter.plugin_oh_my_claudecode.value == "true" ? file("${path.module}/scripts/agents/oh-my-claudecode.sh") : "",
    data.coder_parameter.plugin_oh_my_opencode.value == "true" ? file("${path.module}/scripts/agents/oh-my-opencode.sh") : "",
  ]))

  # Common dependencies script
  common_deps = file("${path.module}/scripts/common-deps.sh")

  # Base AI tools script
  base_ai_tools = file("${path.module}/scripts/base-ai-tools.sh")

  # Determine if we need the oh-my-claudecode install script
  include_oh_my_claudecode_script = data.coder_parameter.plugin_oh_my_claudecode.value == "true"
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

    # Install selected development stacks (no-op if none selected)
    (
      true
      ${local.stack_install}
    ) || echo "Stack installation completed with errors"

    # Install selected AI plugins (no-op if none selected)
    (
      true
      ${local.ai_plugin_install}
    ) || echo "AI plugin installation completed with errors"

    # Create oh-my-claudecode setup script if selected
    %{if local.include_oh_my_claudecode_script}
    cat <<'EOF' > /home/coder/install-oh-my-claudecode.sh
${file("${path.module}/scripts/install-oh-my-claudecode.sh")}
EOF
    chmod +x /home/coder/install-oh-my-claudecode.sh
    %{endif}

    # Install code-server
    if ! command -v code-server &>/dev/null; then
      curl -fsSL https://code-server.dev/install.sh | sh
    fi

    # Start code-server
    code-server --bind-addr 0.0.0.0:13337 --auth none /home/coder >/tmp/code-server.log 2>&1 &
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

  # Bootstrap coder user and run agent as coder
  command = ["sh", "-c", "apt-get update && apt-get install -y curl sudo && (id -u coder >/dev/null 2>&1 || useradd -m -s /bin/bash coder) && echo 'coder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/coder && chmod 440 /etc/sudoers.d/coder && sudo -u coder CODER_AGENT_TOKEN=$CODER_AGENT_TOKEN sh -c '${coder_agent.main.init_script}'"]

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
  icon         = "/icon/opencode.svg"
  command      = "cd /home/coder && opencode"
}


# Codex app - always available (base AI tool)
resource "coder_app" "codex" {
  agent_id     = coder_agent.main.id
  slug         = "codex"
  display_name = "OpenAI Codex"
  icon         = "/icon/openai.svg"
  command      = "cd /home/coder && codex"
}

# Copilot app - always available (base AI tool)
resource "coder_app" "copilot" {
  agent_id     = coder_agent.main.id
  slug         = "copilot"
  display_name = "GitHub Copilot"
  icon         = "/icon/github.svg"
  command      = "cd /home/coder && copilot"
}

# Gemini app - always available (base AI tool)
resource "coder_app" "gemini" {
  agent_id     = coder_agent.main.id
  slug         = "gemini"
  display_name = "Google Gemini"
  icon         = "/icon/gemini.svg"
  command      = "cd /home/coder && gemini"
}
