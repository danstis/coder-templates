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

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

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
    sudo apt-get install -y curl wget git

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

  # Run Coder agent directly
  command = ["sh", "-c", coder_agent.main.init_script]

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
