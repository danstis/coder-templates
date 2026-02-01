#!/usr/bin/env bash
#
# Deploy templates from GitHub releases to a Coder instance.
#
# Usage:
#   ./scripts/deploy-templates.sh [options]
#
# Options:
#   --release <tag>    Deploy a specific release (default: latest)
#   --template <name>  Deploy only a specific template (default: all)
#   --dry-run          Show what would be deployed without executing
#   --help             Show this help message
#
# Environment variables:
#   CODER_URL           Optional. URL of your Coder instance (uses CLI auth if not set)
#   CODER_SESSION_TOKEN Optional. API token for authentication (uses CLI auth if not set)
#   GITHUB_REPO         Optional. Repository (default: danstis/coder-templates)
#
# Requirements:
#   - coder CLI (https://coder.com/docs/install/cli)
#   - gh CLI (https://cli.github.com/) - must be authenticated
#
# Examples:
#   # Deploy latest release (using pre-authenticated CLI)
#   ./scripts/deploy-templates.sh
#
#   # Deploy latest release (with explicit credentials)
#   export CODER_URL=https://coder.example.com
#   export CODER_SESSION_TOKEN=your-token
#   ./scripts/deploy-templates.sh
#
#   # Deploy specific release
#   ./scripts/deploy-templates.sh --release v1.2.0
#
#   # Deploy only ai-dev template
#   ./scripts/deploy-templates.sh --template ai-dev
#

set -euo pipefail

# Default values
RELEASE="latest"
TEMPLATE=""
DRY_RUN=false
GITHUB_REPO="${GITHUB_REPO:-danstis/coder-templates}"

# Template metadata configuration
# Format: template_name|display_name|description|icon
declare -A TEMPLATE_METADATA=(
    ["ai-dev"]="AI Development|Docker-based development environment with AI coding agents, multiple language stacks, and VS Code Web|/icon/code.svg"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Apply template metadata (display name, description, icon)
apply_template_metadata() {
    local template_name="$1"
    
    if [[ -v "TEMPLATE_METADATA[$template_name]" ]]; then
        local metadata="${TEMPLATE_METADATA[$template_name]}"
        local display_name description icon
        
        IFS='|' read -r display_name description icon <<< "$metadata"
        
        log_info "Applying metadata to template: $template_name"
        if coder templates edit "$template_name" \
            --display-name "$display_name" \
            --description "$description" \
            --icon "$icon" \
            --yes; then
            log_info "Metadata applied: display_name='$display_name', icon='$icon'"
            return 0
        else
            log_warn "Failed to apply metadata to $template_name"
            return 1
        fi
    else
        log_info "No metadata configured for template: $template_name"
        return 0
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            RELEASE="$2"
            shift 2
            ;;
        --template)
            TEMPLATE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check for Coder CLI authentication
# If environment variables are set, use them; otherwise assume CLI is pre-authenticated
if [[ -z "${CODER_URL:-}" ]] || [[ -z "${CODER_SESSION_TOKEN:-}" ]]; then
    log_info "CODER_URL or CODER_SESSION_TOKEN not set, assuming Coder CLI is pre-authenticated"
    log_info "If not authenticated, run: coder login https://your-coder-instance.com"
fi

# Check for required tools
for cmd in unzip coder gh; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        case "$cmd" in
            coder)
                echo "  Install Coder CLI: curl -L https://coder.com/install.sh | sh"
                ;;
            gh)
                echo "  Install GitHub CLI: https://cli.github.com/"
                echo "  Then authenticate: gh auth login"
                ;;
        esac
        exit 1
    fi
done

# Create temporary directory
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

log_info "Working directory: $WORK_DIR"

# Fetch release information using gh CLI
log_info "Fetching release info for: $GITHUB_REPO"

if [[ "$RELEASE" == "latest" ]]; then
    RELEASE_INFO=$(gh release view --repo "$GITHUB_REPO" --json tagName,assets 2>&1) || {
        log_error "Failed to fetch release information"
        echo ""
        echo -e "${YELLOW}Possible causes:${NC}"
        echo "  1. No releases have been created yet"
        echo "  2. Not authenticated with gh CLI (run: gh auth login)"
        echo "  3. The repository name is incorrect"
        echo ""
        echo -e "${GREEN}To deploy from local source instead:${NC}"
        echo "  coder templates push ai-dev --directory templates/ai-dev"
        exit 1
    }
else
    RELEASE_INFO=$(gh release view "$RELEASE" --repo "$GITHUB_REPO" --json tagName,assets 2>&1) || {
        log_error "Release not found: $RELEASE"
        exit 1
    }
fi

RELEASE_TAG=$(echo "$RELEASE_INFO" | grep -o '"tagName":"[^"]*"' | cut -d'"' -f4)
log_info "Deploying release: $RELEASE_TAG"

# Get list of zip assets
ASSETS=$(echo "$RELEASE_INFO" | grep -o '"name":"[^"]*\.zip"' | cut -d'"' -f4)

if [[ -z "$ASSETS" ]]; then
    log_error "No template zip files found in release $RELEASE_TAG"
    exit 1
fi

# Filter assets if specific template requested
if [[ -n "$TEMPLATE" ]]; then
    FILTERED_ASSETS=$(echo "$ASSETS" | grep "^${TEMPLATE}\.zip$" || true)
    if [[ -z "$FILTERED_ASSETS" ]]; then
        log_error "Template '$TEMPLATE' not found in release $RELEASE_TAG"
        log_info "Available templates:"
        echo "$ASSETS" | sed 's/\.zip$//' | sed 's/^/  - /'
        exit 1
    fi
    ASSETS="$FILTERED_ASSETS"
fi

# Deploy each template
DEPLOYED=0
FAILED=0

for asset_name in $ASSETS; do
    template_name="${asset_name%.zip}"
    log_info "Processing template: $template_name"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would download: $asset_name"
        log_info "[DRY-RUN] Would push to Coder: $template_name"
        if [[ -v "TEMPLATE_METADATA[$template_name]" ]]; then
            metadata="${TEMPLATE_METADATA[$template_name]}"
            IFS='|' read -r display_name description icon <<< "$metadata"
            log_info "[DRY-RUN] Would apply metadata: display_name='$display_name', icon='$icon'"
        fi
        ((DEPLOYED++))
        continue
    fi
    
    # Download the template zip using gh CLI
    zip_file="$WORK_DIR/${template_name}.zip"
    template_dir="$WORK_DIR/${template_name}"
    
    log_info "Downloading: $asset_name"
    if ! gh release download "$RELEASE_TAG" --repo "$GITHUB_REPO" --pattern "$asset_name" --dir "$WORK_DIR"; then
        log_error "Failed to download $template_name"
        ((FAILED++))
        continue
    fi
    
    # Extract the template
    log_info "Extracting: $zip_file"
    mkdir -p "$template_dir"
    if ! unzip -q "$zip_file" -d "$template_dir"; then
        log_error "Failed to extract $template_name"
        ((FAILED++))
        continue
    fi
    
    # Push to Coder
    log_info "Pushing template to Coder: $template_name"
    
    # Use release tag as version name for traceability
    if coder templates push "$template_name" \
        --directory "$template_dir" \
        --name "$RELEASE_TAG" \
        --message "Deployed from GitHub release $RELEASE_TAG" \
        --yes; then
        log_info "Successfully deployed: $template_name"
        
        # Apply template metadata (display name, description, icon)
        apply_template_metadata "$template_name"
        
        ((DEPLOYED++))
    else
        log_error "Failed to push $template_name to Coder"
        ((FAILED++))
    fi
done

# Summary
echo ""
log_info "Deployment complete!"
log_info "  Release: $RELEASE_TAG"
log_info "  Deployed: $DEPLOYED"
if [[ $FAILED -gt 0 ]]; then
    log_warn "  Failed: $FAILED"
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    log_warn "This was a dry run. No changes were made."
fi
