<#
.SYNOPSIS
    Deploy templates from GitHub releases to a Coder instance.

.DESCRIPTION
    Downloads template zip files from GitHub releases and pushes them to a Coder instance
    using the Coder CLI.

.PARAMETER Release
    The release tag to deploy. Defaults to 'latest'.

.PARAMETER Template
    Deploy only a specific template. If not specified, all templates are deployed.

.PARAMETER DryRun
    Show what would be deployed without executing.

.PARAMETER CoderUrl
    URL of your Coder instance. Can also be set via CODER_URL environment variable.

.PARAMETER CoderToken
    API token for authentication. Can also be set via CODER_SESSION_TOKEN environment variable.

.PARAMETER GitHubRepo
    GitHub repository. Defaults to 'danstis/coder-templates'.

.EXAMPLE
    # Deploy latest release (all templates)
    $env:CODER_URL = "https://coder.example.com"
    $env:CODER_SESSION_TOKEN = "your-token"
    .\deploy-templates.ps1

.EXAMPLE
    # Deploy specific release
    .\deploy-templates.ps1 -Release "v1.2.0"

.EXAMPLE
    # Deploy only ai-dev template
    .\deploy-templates.ps1 -Template "ai-dev"

.EXAMPLE
    # Dry run to see what would be deployed
    .\deploy-templates.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$Release = "latest",
    [string]$Template = "",
    [switch]$DryRun,
    [string]$CoderUrl = $env:CODER_URL,
    [string]$CoderToken = $env:CODER_SESSION_TOKEN,
    [string]$GitHubRepo = "danstis/coder-templates"
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check required environment variables
if ([string]::IsNullOrEmpty($CoderUrl)) {
    Write-Error "CODER_URL is required"
    Write-Host "  Set via parameter: -CoderUrl 'https://your-coder-instance.com'"
    Write-Host "  Or environment variable: `$env:CODER_URL = 'https://your-coder-instance.com'"
    exit 1
}

if ([string]::IsNullOrEmpty($CoderToken)) {
    Write-Error "CODER_SESSION_TOKEN is required"
    Write-Host "  Create a token: coder tokens create"
    Write-Host "  Set via parameter: -CoderToken 'your-token'"
    Write-Host "  Or environment variable: `$env:CODER_SESSION_TOKEN = 'your-token'"
    exit 1
}

# Set environment variables for coder CLI
$env:CODER_URL = $CoderUrl
$env:CODER_SESSION_TOKEN = $CoderToken

# Check for coder CLI
try {
    $null = Get-Command coder -ErrorAction Stop
} catch {
    Write-Error "Coder CLI not found"
    Write-Host "  Install from: https://coder.com/docs/install/cli"
    Write-Host "  Or run: winget install Coder.Coder"
    exit 1
}

# Create temporary directory
$WorkDir = Join-Path $env:TEMP "coder-deploy-$(Get-Random)"
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

try {
    Write-Info "Working directory: $WorkDir"

    # Determine release URL
    if ($Release -eq "latest") {
        $ReleaseApi = "https://api.github.com/repos/$GitHubRepo/releases/latest"
    } else {
        $ReleaseApi = "https://api.github.com/repos/$GitHubRepo/releases/tags/$Release"
    }

    Write-Info "Fetching release info from: $ReleaseApi"

    # Fetch release information
    try {
        $ReleaseInfo = Invoke-RestMethod -Uri $ReleaseApi -ErrorAction Stop
    } catch {
        if ($_.Exception.Response.StatusCode -eq 'NotFound') {
            Write-Error "Release not found: $Release"
            exit 1
        }
        throw
    }

    $ReleaseTag = $ReleaseInfo.tag_name
    Write-Info "Deploying release: $ReleaseTag"

    # Get list of zip assets
    $Assets = $ReleaseInfo.assets | Where-Object { $_.name -like "*.zip" }

    if ($Assets.Count -eq 0) {
        Write-Error "No template zip files found in release $ReleaseTag"
        exit 1
    }

    # Filter assets if specific template requested
    if (-not [string]::IsNullOrEmpty($Template)) {
        $FilteredAssets = $Assets | Where-Object { $_.name -eq "$Template.zip" }
        if ($FilteredAssets.Count -eq 0) {
            Write-Error "Template '$Template' not found in release $ReleaseTag"
            Write-Info "Available templates:"
            $Assets | ForEach-Object { Write-Host "  - $($_.name -replace '\.zip$', '')" }
            exit 1
        }
        $Assets = $FilteredAssets
    }

    # Deploy each template
    $Deployed = 0
    $Failed = 0

    foreach ($Asset in $Assets) {
        $TemplateName = $Asset.name -replace '\.zip$', ''
        Write-Info "Processing template: $TemplateName"

        if ($DryRun) {
            Write-Info "[DRY-RUN] Would download: $($Asset.browser_download_url)"
            Write-Info "[DRY-RUN] Would push to Coder: $TemplateName"
            $Deployed++
            continue
        }

        # Download the template zip
        $ZipFile = Join-Path $WorkDir "$TemplateName.zip"
        $TemplateDir = Join-Path $WorkDir $TemplateName

        Write-Info "Downloading: $($Asset.browser_download_url)"
        try {
            Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $ZipFile -ErrorAction Stop
        } catch {
            Write-Error "Failed to download $TemplateName : $_"
            $Failed++
            continue
        }

        # Extract the template
        Write-Info "Extracting: $ZipFile"
        try {
            New-Item -ItemType Directory -Path $TemplateDir -Force | Out-Null
            Expand-Archive -Path $ZipFile -DestinationPath $TemplateDir -Force
        } catch {
            Write-Error "Failed to extract $TemplateName : $_"
            $Failed++
            continue
        }

        # Push to Coder
        Write-Info "Pushing template to Coder: $TemplateName"

        try {
            $result = & coder templates push $TemplateName `
                --directory $TemplateDir `
                --name $ReleaseTag `
                --message "Deployed from GitHub release $ReleaseTag" `
                --yes 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Info "Successfully deployed: $TemplateName"
                $Deployed++
            } else {
                Write-Error "Failed to push $TemplateName to Coder"
                Write-Host $result
                $Failed++
            }
        } catch {
            Write-Error "Failed to push $TemplateName to Coder: $_"
            $Failed++
        }
    }

    # Summary
    Write-Host ""
    Write-Info "Deployment complete!"
    Write-Info "  Release: $ReleaseTag"
    Write-Info "  Deployed: $Deployed"

    if ($Failed -gt 0) {
        Write-Warn "  Failed: $Failed"
        exit 1
    }

    if ($DryRun) {
        Write-Warn "This was a dry run. No changes were made."
    }

} finally {
    # Cleanup
    if (Test-Path $WorkDir) {
        Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
