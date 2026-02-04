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

### Modular Script Architecture

The template uses modular installation scripts loaded via Terraform's `file()` function:

**Scripts Directory:**
```
scripts/
├── common-deps.sh          # Shared dependencies (Node 24, gh CLI, always executed)
├── base-ai-tools.sh        # All 6 base AI CLI tools (parallel installation)
├── install-oh-my-claudecode.sh
├── stacks/                 # Development stack installers
│   ├── python-uv.sh
│   ├── python-pip.sh
│   └── go.sh
├── agents/                 # AI plugin installers (optional enhancements)
│   ├── oh-my-claudecode.sh
│   └── oh-my-opencode.sh
└── tools/                  # Optional tool installers
    └── vibe-kanban.sh
```

**Terraform Implementation:**
```hcl
locals {
  # Load scripts using file() function
  stack_install = lookup({
    "python-uv"  = file("${path.module}/scripts/stacks/python-uv.sh")
    "python-pip" = file("${path.module}/scripts/stacks/python-pip.sh")
    # ... other options
  }, data.coder_parameter.stack.value, "default")
}
```

Benefits of this approach:
- Scripts are external files, not inline in Terraform
- Easy to add new stacks/agents without modifying main.tf
- Better readability and maintainability
- Scripts can be tested independently
- Clear separation of concerns between Terraform logic and installation logic

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

1. **Run common-deps.sh** - Installs sudo, creates coder user, installs shared dependencies (curl, wget, git, expect, Node.js 24, gh CLI)
2. **Run base-ai-tools.sh** - Installs all 6 AI CLI tools in parallel (claude, opencode, relentless, codex, copilot, gemini)
3. **Run stack script** - Installs selected development stack based on parameter
4. **Run plugin script** - Installs selected AI plugin based on parameter (oh-my-claudecode/oh-my-opencode)
5. **Run optional tool script** - Installs selected optional tool based on parameter (vibe-kanban)
6. **Create oh-my-claudecode setup script** (conditional) - Only if oh-my-claudecode is selected
7. **Start Vibe Kanban web UI** (conditional) - Only if vibe-kanban is selected, on port 5173
8. **Install code-server** - If not already present
9. **Start code-server** - In background on port 13337

Each installation step is wrapped in a subshell with `|| echo` for non-fatal error handling, allowing the container to start even if optional installations fail.

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
- **none**: No stack installed

Note: Node.js 24 is now always available in the base image via common-deps.sh.

### Base AI Tools (Always Installed)
All 6 base AI CLI tools are automatically installed in every workspace:
- **Claude Code** (@anthropic-ai/claude-code) - Anthropic's AI coding assistant
- **OpenCode** (opencode-ai) - Open-source AI coding assistant
- **Relentless** (@arvorco/relentless) - Uses Claude Code for persistent coding
- **Codex** (@openai/codex) - OpenAI's coding assistant
- **Copilot** (@github/copilot) - GitHub's AI pair programmer
- **Gemini** (@google/gemini-cli) - Google's AI coding assistant

### AI Plugins (Optional)
Plugins enhance the base tools with additional features:
- **oh-my-claudecode**: Enhances Claude Code with additional configuration
- **oh-my-opencode**: Enhances OpenCode with additional features
- **none**: No plugin (default)

### Optional Tools
Additional productivity tools that can be installed in the workspace:
- **vibe-kanban**: Kanban board for project management (installed via `npm install -g vibe-kanban`). Includes a web UI accessible as a Coder app on port 5173, plus a terminal CLI app.
- **none**: No optional tool (default)

## Extending the Template

### Adding a New Development Stack

To add a new development stack option:

1. **Create the installation script** at `scripts/stacks/your-stack.sh`:
   ```bash
   #!/bin/bash
   # your-stack.sh - Install Your Stack
   # Requires: apt (from common-deps.sh)
   set -e

   sudo apt-get install -y your-stack-package
   ```

2. **Add parameter option** in `main.tf`:
   ```hcl
   option {
     name  = "Your Stack"
     value = "your-stack"
     icon  = "/icon/your-icon.svg"
   }
   ```

3. **Add to lookup** in the locals block:
   ```hcl
   "your-stack" = file("${path.module}/scripts/stacks/your-stack.sh")
   ```

### Adding a New AI Agent

To add a new base AI tool (installed in all workspaces):

1. **Update base-ai-tools.sh** at `scripts/base-ai-tools.sh`:
   - Add the npm install command with background execution (`&`)
   - Add the wait command with success/failure messaging
   - Follow the existing parallel installation pattern

2. **Add a coder_app resource** in `main.tf` following the existing pattern

To add a new AI plugin option (optional enhancement):

1. **Create the installation script** at `scripts/agents/your-plugin.sh`:
   ```bash
   #!/bin/bash
   # your-plugin.sh - Install Your Plugin
   # Requires: Base tool (from base-ai-tools.sh), Node.js and npm (from common-deps.sh)
   set -e

   sudo npm install -g your-plugin-package
   ```

2. **Add parameter option** in `main.tf` under `data "coder_parameter" "ai_plugin"`

3. **Add to lookup** in the locals block under `ai_plugin_install`

### Adding a New Optional Tool

To add a new optional tool:

1. **Create the installation script** at `scripts/tools/your-tool.sh`:
   ```bash
   #!/bin/bash
   # your-tool.sh - Install Your Tool
   # Requires: Node.js and npm (from common-deps.sh)
   set -e

   sudo npm install -g your-tool-package
   ```

2. **Add parameter option** in `main.tf` under `data "coder_parameter" "optional_tool"`:
   ```hcl
   option {
     name  = "Your Tool"
     value = "your-tool"
     icon  = "/icon/your-icon.svg"
   }
   ```

3. **Add to lookup** in the locals block under `optional_tool_install`:
   ```hcl
   "your-tool" = file("${path.module}/scripts/tools/your-tool.sh")
   ```

### Script Writing Guidelines

- All scripts require `#!/bin/bash` shebang
- Include descriptive header comments
- Document dependencies (which common scripts they rely on)
- Use `set -e` to exit on errors
- Use `sudo` for privileged operations (runs as root in container)
- Use `sudo -u coder` for operations that should run as the coder user
- Wrap npm installs with `sudo` for global packages
- Use `|| echo` in startup_script for non-fatal error handling

## Icon Guidelines

### Using Coder Built-in Icons

Coder provides 137+ built-in icons at `/icon/`. Always prefer these over custom icons to avoid licensing concerns and ensure consistency.

**Icon Reference:**

| Icon | Path | Use For |
|------|------|---------|
| Python | `/icon/python.svg` | Python stacks |
| Go | `/icon/go.svg` | Go stack |
| VS Code | `/icon/code.svg` | VS Code, generic code, "None" options |
| Claude | `/icon/claude.svg` | Claude Code, Oh-My-ClaudeCode |
| OpenCode | `/icon/opencode.svg` | OpenCode, Oh-My-OpenCode |
| OpenAI | `/icon/openai.svg` | Codex |
| GitHub | `/icon/github.svg` | Copilot |
| Gemini | `/icon/gemini.svg` | Gemini CLI |
| Terminal | `/icon/terminal.svg` | Generic CLI tools (fallback) |
| Task | `/icon/task.svg` | Project management tools (fallback) |
| Vibe Kanban | `https://www.vibekanban.com/favicon.png` | Vibe Kanban |

**Browse all available icons:** https://github.com/coder/coder/tree/main/site/static/icon

### Adding Icons to Templates

When adding new `coder_parameter` options or `coder_app` resources:

1. **Check Coder's built-in icons first** - Most common tools/languages are already available
2. **Use recognizable brand icons** - Match the tool/service being represented
3. **Fallback to generic icons** - Use `/icon/terminal.svg` or `/icon/code.svg` if no specific icon exists
4. **Be consistent** - Use the same icon for related resources (e.g., OpenCode app and Oh-My-OpenCode plugin)

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

### Vibe Kanban Port

When selected, Vibe Kanban runs on port 5173 (set via `PORT` env var in the startup script and referenced in the `coder_app` URL). Must be changed in both locations if modified.

## Monitoring

The agent includes three metadata collectors that report to the Coder dashboard:
- CPU usage (`coder stat cpu`)
- RAM usage (`coder stat mem`)
- Disk usage (`coder stat disk --path /home/coder`)

All run every 10 seconds with 1-second timeout.

## Documentation Maintenance

### Keep README.md Up to Date

**CRITICAL**: Whenever you make changes to the repository, you MUST update README.md if the changes affect:

1. **Available templates** - Adding/removing/renaming templates
2. **Template features** - New development stacks, AI agents, or capabilities
3. **Development workflow** - Changes to build, test, or deployment processes
4. **Release process** - Modifications to GitHub Actions, versioning, or packaging
5. **Project structure** - New directories, moved files, or organizational changes
6. **Prerequisites** - New tools or version requirements
7. **Configuration** - New settings or parameters

### Update Checklist

Before completing any task that modifies the repository, verify:

- [ ] Does this change affect how users interact with templates?
- [ ] Did I add/modify/remove any template parameters?
- [ ] Did I change the development workflow or commands?
- [ ] Did I add new scripts or automation?
- [ ] Did I modify the release or packaging process?
- [ ] Did I add new dependencies or requirements?

If ANY checkbox is YES, update the corresponding section in README.md.

### Common Update Scenarios

| Change Made | README Section to Update |
|-------------|--------------------------|
| Added new template | "Available Templates" + "Project Structure" |
| Added development stack option | "Available Templates" → template features |
| Modified packaging script | "Release Process" → "How It Works" |
| Added new workflow step | "Development" → "Template Development Workflow" |
| Changed versioning strategy | "Release Process" → "Versioning Strategy" |
| Updated prerequisites | "Development" → "Prerequisites" |
| Modified conventional commit rules | "Release Process" → "Commit Message Format" |

### Documentation Standards

When updating README.md:
- Keep it accurate and synchronized with actual code
- Use concrete examples from the codebase
- Update version numbers and command outputs if they changed
- Verify all links and file paths are correct
- Test all code snippets and commands
- Maintain consistent formatting and style
- Keep the table of contents aligned with sections

## Commit and PR Guidelines

### Conventional Commits Required

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and releases. Both commit messages and PR titles MUST follow this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types and Version Bumping

| Type | Version Bump | When to Use |
|------|--------------|-------------|
| `fix:` | Patch (0.0.x) | Bug fixes |
| `feat:` | Minor (0.x.0) | New features |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) | Breaking changes |
| `docs:` | None | Documentation only |
| `chore:` | None | Maintenance tasks |
| `style:` | None | Code style changes |
| `refactor:` | None | Code refactoring |
| `test:` | None | Test additions/changes |
| `ci:` | None | CI/CD changes |

### Examples

```bash
# Patch release - bug fix
fix(ai-dev): resolve code-server startup timing issue

# Minor release - new feature
feat(ai-dev): add Rust development stack option

# Major release - breaking change
feat!: redesign template parameter structure

BREAKING CHANGE: templates now require Coder v2.5 or higher

# No release - documentation
docs: update ai-dev README with troubleshooting steps
```

### Pull Request Titles

**IMPORTANT**: PR titles must also follow conventional commit format because when PRs are squash-merged, the PR title becomes the commit message that triggers versioning.

Good PR titles:
- `feat(ai-dev): add support for Java development stack`
- `fix: correct Docker volume permissions issue`
- `docs: improve README installation instructions`

Bad PR titles:
- `Add Java support` (missing type and scope)
- `Fix bug` (too vague)
- `Update docs` (missing conventional format)

### Workflow

1. Create feature branch from `main`
2. Make changes with descriptive conventional commits
3. Create PR with conventional commit title
4. PR is reviewed and squash-merged to `main`
5. GitHub Actions automatically:
   - Determines version bump from PR title (now the commit message)
   - Creates git tag
   - Packages templates
   - Creates GitHub release with artifacts
