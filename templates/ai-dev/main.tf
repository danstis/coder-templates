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

# --- AI Plugins (order 4-5, immutable) ---
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

# --- Persistent Mounts (order 10-13, mutable) ---
data "coder_parameter" "persist_vscode" {
  name         = "persist_vscode"
  display_name = "Persist VS Code Settings"
  description  = "Persist VS Code Server extensions and settings across workspaces (per-user)"
  icon         = "/icon/code.svg"
  type         = "bool"
  default      = "true"
  mutable      = true
  order        = 10
}

data "coder_parameter" "persist_cli_config" {
  name         = "persist_cli_config"
  display_name = "Persist CLI Config"
  description  = "Persist CLI tool configuration (~/.config) across workspaces (per-user)"
  icon         = "/icon/terminal.svg"
  type         = "bool"
  default      = "true"
  mutable      = true
  order        = 11
}

data "coder_parameter" "persist_ssh" {
  name         = "persist_ssh"
  display_name = "Persist SSH Config"
  description  = "Persist SSH keys and configuration across workspaces (per-user)"
  icon         = "/icon/terminal.svg"
  type         = "bool"
  default      = "true"
  mutable      = true
  order        = 12
}

data "coder_parameter" "persist_repos" {
  name         = "persist_repos"
  display_name = "Persist Code Repos"
  description  = "Persist ~/github.com and ~/dev.azure.com directories across workspaces (per-user)"
  icon         = "/icon/github.svg"
  type         = "bool"
  default      = "true"
  mutable      = true
  order        = 13
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

  # Persistent mount permissions fix script
  fix_persistent_mount_permissions = file("${path.module}/scripts/fix-persistent-mount-permissions.sh")

  # Determine if we need the oh-my-claudecode install script
  include_oh_my_claudecode_script = data.coder_parameter.plugin_oh_my_claudecode.value == "true"

  # Determine if we need the oh-my-opencode wrapper script
  include_oh_my_opencode_wrapper = data.coder_parameter.plugin_oh_my_opencode.value == "true"
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

# --- Per-user persistent volumes (shared across workspaces for the same owner) ---
resource "docker_volume" "vscode_volume" {
  count = data.coder_parameter.persist_vscode.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-vscode"
}

resource "docker_volume" "cli_config_volume" {
  count = data.coder_parameter.persist_cli_config.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-config"
}

resource "docker_volume" "ssh_volume" {
  count = data.coder_parameter.persist_ssh.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-ssh"
}

resource "docker_volume" "github_volume" {
  count = data.coder_parameter.persist_repos.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-github"
}

resource "docker_volume" "azuredevops_volume" {
  count = data.coder_parameter.persist_repos.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-azuredevops"
}

# Oh-my-* plugin config volumes (auto-tied to plugin selection)
resource "docker_volume" "claude_omc_volume" {
  count = data.coder_parameter.plugin_oh_my_claudecode.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-claude-omc"
}

resource "docker_volume" "opencode_omc_volume" {
  count = data.coder_parameter.plugin_oh_my_opencode.value == "true" ? 1 : 0
  name  = "coder-${data.coder_workspace_owner.me.name}-opencode-omc"
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Fix ownership on per-user persistent mount volumes (runs as coder with sudo)
    ${local.fix_persistent_mount_permissions}

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

    # Create oh-my-opencode wrapper script if plugin selected
    %{if local.include_oh_my_opencode_wrapper}
    cat <<'EOF' > /home/coder/opencode-wrapper.sh
${file("${path.module}/scripts/agents/opencode-wrapper.sh")}
EOF
    chmod +x /home/coder/opencode-wrapper.sh
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

  # Per-user persistent mounts (conditional)
  dynamic "volumes" {
    for_each = data.coder_parameter.persist_vscode.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/.vscode-server"
      volume_name    = docker_volume.vscode_volume[0].name
    }
  }

  dynamic "volumes" {
    for_each = data.coder_parameter.persist_cli_config.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/.config"
      volume_name    = docker_volume.cli_config_volume[0].name
    }
  }

  dynamic "volumes" {
    for_each = data.coder_parameter.persist_ssh.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/.ssh"
      volume_name    = docker_volume.ssh_volume[0].name
    }
  }

  dynamic "volumes" {
    for_each = data.coder_parameter.persist_repos.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/github.com"
      volume_name    = docker_volume.github_volume[0].name
    }
  }

  dynamic "volumes" {
    for_each = data.coder_parameter.persist_repos.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/dev.azure.com"
      volume_name    = docker_volume.azuredevops_volume[0].name
    }
  }

  # Oh-my-* plugin config volumes (auto-tied to plugin selection)
  dynamic "volumes" {
    for_each = data.coder_parameter.plugin_oh_my_claudecode.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/.claude"
      volume_name    = docker_volume.claude_omc_volume[0].name
    }
  }

  dynamic "volumes" {
    for_each = data.coder_parameter.plugin_oh_my_opencode.value == "true" ? [1] : []
    content {
      container_path = "/home/coder/.config/opencode"
      volume_name    = docker_volume.opencode_omc_volume[0].name
    }
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
# Uses wrapper script for first-run oh-my-opencode setup if plugin is enabled
resource "coder_app" "opencode" {
  agent_id     = coder_agent.main.id
  slug         = "opencode"
  display_name = "OpenCode"
  icon         = "/icon/opencode.svg"
  command      = local.include_oh_my_opencode_wrapper ? "cd /home/coder && ./opencode-wrapper.sh" : "cd /home/coder && opencode"
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
