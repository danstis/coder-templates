# Coder Templates

A collection of [Coder](https://coder.com) workspace templates for creating development environments with pre-configured tooling and AI coding agents.

## Overview

This repository contains Terraform-based templates that provision containerized development workspaces using Coder. Each template provides a complete, ready-to-use development environment with persistent storage, web-based IDE access, and optional AI coding assistants.

## Available Templates

### ai-dev

A Docker-based universal AI agentic coding workspace with all major CLI tools pre-installed.

| Property | Value |
|----------|-------|
| **Display Name** | AI Development |
| **Description** | Universal AI workspace with 6 pre-installed AI CLI tools (Claude Code, OpenCode, Relentless, Codex, Gemini, Copilot), multiple language stacks, and VS Code Web |
| **Icon** | `/icon/code.svg` |

**Features:**
- Ubuntu 24.04 LTS base image
- code-server (VS Code in the browser) on port 13337
- Persistent home directory storage
- **Base AI Tools** (always installed): Claude Code, OpenCode, Relentless, OpenAI Codex, GitHub Copilot, Google Gemini
- Multi-select development stacks: Python (uv), Python (pip), Go — enable any combination
- Multi-select AI plugins: Oh-My-ClaudeCode, Oh-My-OpenCode, Agent OS — enable any combination
- Node.js 24 and GitHub CLI included in base
- Pre-configured Git author/committer from Coder profile
- Real-time resource monitoring (CPU, RAM, disk)
- Local VS Code connection support via Coder CLI

See [templates/ai-dev/README.md](templates/ai-dev/README.md) for detailed documentation including import instructions.

## AI Tool Authentication

All pre-installed AI CLI tools require authentication before use. Below are the authentication requirements for each tool:

| Tool | Authentication Method | Required |
|------|----------------------|----------|
| **Claude Code** | Anthropic API key or `claude login` | Yes - API key or account |
| **OpenCode** | `opencode auth login` (provider-specific) | Yes - provider account |
| **Relentless** | Uses Claude Code auth | Yes - Anthropic API key |
| **Codex** | ChatGPT Plus/Pro or OpenAI API key | Yes - subscription or API key |
| **Copilot** | GitHub Copilot subscription | Yes - GitHub Copilot license |
| **Gemini** | `GOOGLE_API_KEY` env var or gcloud auth | Yes - Google account or API key |

### Setting Up Authentication

**Environment Variables (Recommended)**:
```bash
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
export GOOGLE_API_KEY="your-key-here"
```

**Interactive Login**:
```bash
# Claude Code
claude login

# OpenCode (provider-specific)
opencode auth login

# Codex (may require device auth in headless)
codex login --device-auth
```

**Note**: In headless Docker environments, prefer API key authentication via environment variables.

## Deployment

Use the deployment scripts to deploy templates from GitHub releases to your Coder instance.

### Prerequisites

1. Install the [Coder CLI](https://coder.com/docs/install/cli) and authenticate:
   ```bash
   coder login https://your-coder-instance.com
   ```

2. Install the [GitHub CLI](https://cli.github.com/) and authenticate:
   ```bash
   gh auth login
   ```

### Linux/macOS (Bash)

```bash
# Deploy latest release (using pre-authenticated CLI)
./scripts/deploy-templates.sh

# Or with explicit credentials
export CODER_URL=https://your-coder-instance.com
export CODER_SESSION_TOKEN=your-token
./scripts/deploy-templates.sh

# Deploy a specific release
./scripts/deploy-templates.sh --release v1.2.0

# Deploy latest pre-release (from PR builds)
./scripts/deploy-templates.sh --prerelease

# Deploy only a specific template
./scripts/deploy-templates.sh --template ai-dev

# Dry run to see what would be deployed
./scripts/deploy-templates.sh --dry-run
```

### Windows (PowerShell)

```powershell
# Deploy latest release (using pre-authenticated CLI)
.\scripts\deploy-templates.ps1

# Or with explicit credentials
$env:CODER_URL = "https://your-coder-instance.com"
$env:CODER_SESSION_TOKEN = "your-token"
.\scripts\deploy-templates.ps1

# Deploy a specific release
.\scripts\deploy-templates.ps1 -Release "v1.2.0"

# Deploy latest pre-release (from PR builds)
.\scripts\deploy-templates.ps1 -Prerelease

# Deploy only a specific template
.\scripts\deploy-templates.ps1 -Template "ai-dev"

# Dry run to see what would be deployed
.\scripts\deploy-templates.ps1 -DryRun

# Or pass credentials directly
.\scripts\deploy-templates.ps1 -CoderUrl "https://coder.example.com" -CoderToken "your-token"
```

### From Source

1. Clone this repository:
   ```bash
   git clone https://github.com/danstis/coder-templates.git
   cd coder-templates
   ```

2. Push a template to your Coder deployment:
   ```bash
   coder templates push ai-dev --directory templates/ai-dev
   ```

3. Create a workspace from the template in your Coder dashboard

## Development

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Docker](https://docs.docker.com/get-docker/) for testing
- [Coder CLI](https://coder.com/docs/v2/latest/install) for deployment
- Access to a Coder deployment

### Template Development Workflow

1. **Make changes** to a template in `templates/<template-name>/`

2. **Validate syntax**:
   ```bash
   cd templates/ai-dev
   terraform init
   terraform validate
   ```

3. **Test locally** by pushing to your Coder deployment:
   ```bash
   coder templates push ai-dev --directory templates/ai-dev
   ```

4. **Create a test workspace** from the template in Coder dashboard

5. **Commit changes** using [Conventional Commits](#commit-message-format):
   ```bash
   git add .
   git commit -m "feat(ai-dev): add support for Rust development stack"
   git push
   ```

### Adding a New Template

1. Create a new directory in `templates/`:
   ```bash
   mkdir templates/new-template
   ```

2. Add required files:
   - `main.tf` - Terraform configuration
   - `README.md` - Template documentation

3. Follow the existing template patterns (see `templates/ai-dev/` for reference)

4. Test thoroughly before committing

## Release Process

Releases are **fully automated** via GitHub Actions. The workflow is triggered on every push to the `main` branch and on pull requests.

### How It Works

**Production Releases (push to main):**

1. **Packaging**: All templates in `templates/` are automatically packaged into zip files using `scripts/package-template.sh`

2. **Versioning**: The version is automatically determined based on commit messages using [Conventional Commits](https://www.conventionalcommits.org/)

3. **Tagging**: A new git tag is created automatically (e.g., `v0.0.3`, `v0.1.0`, `v1.0.0`)

4. **Release Creation**: A GitHub release is created with:
   - Release notes generated from commit messages
   - All packaged template zip files as downloadable assets

**Pre-releases (pull requests):**

1. **Packaging**: Templates are packaged the same way as production releases

2. **Pre-release Versioning**: A semver pre-release tag is created using the format:
   ```
   v{major}.{minor}.{patch+1}-pr.{pr_number}.{run_number}
   ```
   For example, if the latest release is `v1.2.3` and PR #42 triggers run #15, the pre-release will be `v1.2.4-pr.42.15`

3. **Pre-release Creation**: A GitHub pre-release is created with:
   - Pre-release flag enabled (not shown as "latest")
   - PR title and description in release notes
   - All packaged template zip files for testing

### Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) to control version bumping.

**IMPORTANT**: Both commit messages AND pull request titles must follow conventional commit format. When PRs are squash-merged, the PR title becomes the commit message that triggers versioning.

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix:` | Patch (0.0.x) | `fix(ai-dev): resolve code-server startup issue` |
| `feat:` | Minor (0.x.0) | `feat(ai-dev): add Rust development stack option` |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) | `feat!: redesign template parameter structure` |
| `docs:`, `chore:`, `style:`, `refactor:`, `test:`, `ci:` | No release | `docs: update README installation steps` |

**Examples:**

```bash
# Patch release (v0.0.2 → v0.0.3)
git commit -m "fix(ai-dev): correct terraform provider version constraint"

# Minor release (v0.0.3 → v0.1.0)
git commit -m "feat: add new golang-dev template"

# Major release (v0.1.0 → v1.0.0)
git commit -m "feat!: change template directory structure

BREAKING CHANGE: templates now require Coder v2.5 or higher"

# No release (documentation only)
git commit -m "docs: add troubleshooting section to ai-dev README"
```

### Versioning Strategy

This project follows [Semantic Versioning](https://semver.org/):

- **Major version** (x.0.0): Breaking changes requiring user action
- **Minor version** (0.x.0): New features, backward compatible
- **Patch version** (0.0.x): Bug fixes, backward compatible

Since templates are in active development, versions are currently in the `0.x.x` range. Version `1.0.0` will be released when the templates are considered stable and production-ready.

### Manual Release

Releases are automated, but if you need to create a release manually:

1. Ensure all changes are committed and pushed to `main`
2. The GitHub Actions workflow will automatically:
   - Package templates
   - Bump version based on commits
   - Create release with assets

No manual intervention is required.

## Project Structure

```
coder-templates/
├── .github/
│   └── workflows/
│       └── package-templates.yml  # Automated release workflow
├── scripts/
│   ├── deploy-templates.ps1       # Deployment script (Windows)
│   ├── deploy-templates.sh        # Deployment script (Linux/macOS)
│   └── package-template.sh        # Template packaging script
├── templates/
│   └── ai-dev/
│       ├── main.tf                # Terraform configuration
│       ├── README.md              # Template documentation
│       ├── scripts/
│       │   ├── common-deps.sh     # Shared dependencies (Node 24, gh CLI)
│       │   ├── base-ai-tools.sh   # All 6 base AI CLI tools
│       │   ├── install-oh-my-claudecode.sh
│       │   ├── stacks/            # Development stack installers
│       │   │   ├── python-uv.sh
│       │   │   ├── python-pip.sh
│       │   │   └── go.sh
│       │   └── agents/            # AI plugin installers
│       │       ├── oh-my-claudecode.sh
│       │       ├── oh-my-opencode.sh
│       │       └── agent-os.sh
├── CLAUDE.md                      # AI assistant guidance
└── README.md                      # This file
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the development workflow
4. Test thoroughly with a Coder deployment
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/) format
6. Submit a pull request with:
   - **Title in Conventional Commit format** (e.g., `feat(ai-dev): add Java stack support`)
   - Clear description of changes
   - Test results or screenshots if applicable

**Important**: PR titles must follow conventional commit format because when squash-merged, the PR title becomes the commit message that triggers automatic versioning and releases.

## License

This project is provided as-is for use with Coder deployments.

## Support

- **Issues**: Report bugs or request features via [GitHub Issues](https://github.com/danstis/coder-templates/issues)
- **Documentation**: See individual template READMEs in `templates/`
- **Coder Docs**: https://coder.com/docs
