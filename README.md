# Coder Templates

A collection of [Coder](https://coder.com) workspace templates for creating development environments with pre-configured tooling and AI coding agents.

## Overview

This repository contains Terraform-based templates that provision containerized development workspaces using Coder. Each template provides a complete, ready-to-use development environment with persistent storage, web-based IDE access, and optional AI coding assistants.

## Available Templates

### ai-dev

A Docker-based development workspace optimized for AI-assisted development workflows.

**Features:**
- Ubuntu 24.04 LTS base image
- code-server (VS Code in the browser) on port 13337
- Persistent home directory storage
- Choice of development stacks: Python (uv/pip), Go, Node.js
- Choice of AI agents: Claude Code, OpenCode, Oh-My-ClaudeCode, Oh-My-OpenCode, Relentless
- Pre-configured Git author/committer from Coder profile
- Real-time resource monitoring (CPU, RAM, disk)
- Local VS Code connection support via Coder CLI

See [templates/ai-dev/README.md](templates/ai-dev/README.md) for detailed documentation.

## Deployment

### Automated Deployment (CI/CD)

Templates can be automatically deployed to your Coder instance when new releases are created.

**Setup:**

1. Create a Coder API token:
   ```bash
   coder tokens create --name github-actions --lifetime 8760h
   ```

2. Add repository secrets in GitHub:
   - `CODER_URL` - Your Coder instance URL (e.g., `https://coder.example.com`)
   - `CODER_SESSION_TOKEN` - The API token created above

3. Add a repository variable:
   - `CODER_DEPLOY_ENABLED` = `true` (enables automatic deployment)

4. Templates will now auto-deploy when releases are published.

**Manual trigger**: You can also trigger deployment manually via Actions → "Deploy Templates to Coder" → Run workflow.

### Manual Deployment

Use the deployment script to deploy templates from GitHub releases:

```bash
# Set required environment variables
export CODER_URL=https://your-coder-instance.com
export CODER_SESSION_TOKEN=your-token

# Deploy latest release (all templates)
./scripts/deploy-templates.sh

# Deploy a specific release
./scripts/deploy-templates.sh --release v1.2.0

# Deploy only a specific template
./scripts/deploy-templates.sh --template ai-dev

# Dry run to see what would be deployed
./scripts/deploy-templates.sh --dry-run
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

Releases are **fully automated** via GitHub Actions. The workflow is triggered on every push to the `main` branch.

### How It Works

1. **Packaging**: All templates in `templates/` are automatically packaged into zip files using `scripts/package-template.sh`

2. **Versioning**: The version is automatically determined based on commit messages using [Conventional Commits](https://www.conventionalcommits.org/)

3. **Tagging**: A new git tag is created automatically (e.g., `v0.0.3`, `v0.1.0`, `v1.0.0`)

4. **Release Creation**: A GitHub release is created with:
   - Release notes generated from commit messages
   - All packaged template zip files as downloadable assets

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
│       ├── deploy-templates.yml   # Coder deployment workflow
│       └── package-templates.yml  # Automated release workflow
├── scripts/
│   ├── deploy-templates.sh        # Manual deployment script
│   └── package-template.sh        # Template packaging script
├── templates/
│   └── ai-dev/
│       ├── main.tf                # Terraform configuration
│       ├── README.md              # Template documentation
│       ├── scripts/
│       │   ├── common-deps.sh     # Shared dependency installation
│       │   ├── install-oh-my-claudecode.sh
│       │   ├── stacks/            # Development stack installers
│       │   │   ├── python-uv.sh
│       │   │   ├── python-pip.sh
│       │   │   ├── go.sh
│       │   │   └── node.sh
│       │   └── agents/            # AI agent installers
│       │       ├── claude.sh
│       │       ├── opencode.sh
│       │       ├── oh-my-claudecode.sh
│       │       ├── oh-my-opencode.sh
│       │       └── relentless.sh
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
