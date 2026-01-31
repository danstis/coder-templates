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
#   CODER_URL           Required. URL of your Coder instance
#   CODER_SESSION_TOKEN Required. API token for authentication
#   GITHUB_REPO         Optional. Repository (default: danstis/coder-templates)
#
# Examples:
#   # Deploy latest release (all templates)
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

# Check required environment variables
if [[ -z "${CODER_URL:-}" ]]; then
    log_error "CODER_URL environment variable is required"
    echo "  export CODER_URL=https://your-coder-instance.com"
    exit 1
fi

if [[ -z "${CODER_SESSION_TOKEN:-}" ]]; then
    log_error "CODER_SESSION_TOKEN environment variable is required"
    echo "  Create a token: coder tokens create"
    echo "  export CODER_SESSION_TOKEN=your-token"
    exit 1
fi

# Check for required tools
for cmd in curl unzip coder; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        if [[ "$cmd" == "coder" ]]; then
            echo "  Install Coder CLI: curl -L https://coder.com/install.sh | sh"
        fi
        exit 1
    fi
done

# Create temporary directory
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

log_info "Working directory: $WORK_DIR"

# Determine release URL
if [[ "$RELEASE" == "latest" ]]; then
    RELEASE_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
else
    RELEASE_API="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${RELEASE}"
fi

log_info "Fetching release info from: $RELEASE_API"

# Fetch release information
RELEASE_INFO=$(curl -sL "$RELEASE_API")

if echo "$RELEASE_INFO" | grep -q '"message": "Not Found"'; then
    log_error "Release not found: $RELEASE"
    exit 1
fi

RELEASE_TAG=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
log_info "Deploying release: $RELEASE_TAG"

# Get list of zip assets
ASSETS=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url": "[^"]*\.zip"' | cut -d'"' -f4)

if [[ -z "$ASSETS" ]]; then
    log_error "No template zip files found in release $RELEASE_TAG"
    exit 1
fi

# Filter assets if specific template requested
if [[ -n "$TEMPLATE" ]]; then
    FILTERED_ASSETS=$(echo "$ASSETS" | grep "/${TEMPLATE}\.zip$" || true)
    if [[ -z "$FILTERED_ASSETS" ]]; then
        log_error "Template '$TEMPLATE' not found in release $RELEASE_TAG"
        log_info "Available templates:"
        echo "$ASSETS" | sed 's/.*\//  - /' | sed 's/\.zip$//'
        exit 1
    fi
    ASSETS="$FILTERED_ASSETS"
fi

# Deploy each template
DEPLOYED=0
FAILED=0

for asset_url in $ASSETS; do
    template_name=$(basename "$asset_url" .zip)
    log_info "Processing template: $template_name"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would download: $asset_url"
        log_info "[DRY-RUN] Would push to Coder: $template_name"
        ((DEPLOYED++))
        continue
    fi
    
    # Download the template zip
    zip_file="$WORK_DIR/${template_name}.zip"
    template_dir="$WORK_DIR/${template_name}"
    
    log_info "Downloading: $asset_url"
    if ! curl -sL "$asset_url" -o "$zip_file"; then
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
