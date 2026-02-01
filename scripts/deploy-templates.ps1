<#
.SYNOPSIS
    Deploy templates from GitHub releases to a Coder instance.

.DESCRIPTION
    Downloads template zip files from GitHub releases and pushes them to a Coder instance
    using the Coder CLI. Uses the GitHub CLI (gh) for authenticated access to releases.

.PARAMETER Release
    The release tag to deploy. Defaults to 'latest'.

.PARAMETER Prerelease
    Deploy the latest pre-release version (from PR builds).

.PARAMETER Template
    Deploy only a specific template. If not specified, all templates are deployed.

.PARAMETER DryRun
    Show what would be deployed without executing.

.PARAMETER CoderUrl
    URL of your Coder instance. Optional - uses CLI authentication if not set.

.PARAMETER CoderToken
    API token for authentication. Optional - uses CLI authentication if not set.

.PARAMETER GitHubRepo
    GitHub repository. Defaults to 'danstis/coder-templates'.

.EXAMPLE
    # Deploy latest release (using pre-authenticated CLI)
    .\deploy-templates.ps1

.EXAMPLE
    # Deploy latest release (with explicit credentials)
    $env:CODER_URL = "https://coder.example.com"
    $env:CODER_SESSION_TOKEN = "your-token"
    .\deploy-templates.ps1

.EXAMPLE
    # Deploy specific release
    .\deploy-templates.ps1 -Release "v1.2.0"

.EXAMPLE
    # Deploy latest pre-release (from PR)
    .\deploy-templates.ps1 -Prerelease

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
    [switch]$Prerelease,
    [string]$Template = "",
    [switch]$DryRun,
    [string]$CoderUrl = $env:CODER_URL,
    [string]$CoderToken = $env:CODER_SESSION_TOKEN,
    [string]$GitHubRepo = "danstis/coder-templates"
)

$ErrorActionPreference = "Stop"

# Template metadata configuration
# Each entry contains: DisplayName, Description, Icon
$TemplateMetadata = @{
    "ai-dev" = @{
        DisplayName = "AI Development"
        Description = "Docker-based development environment with AI coding agents, multiple language stacks, and VS Code Web"
        Icon = "/icon/code.svg"
    }
}

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

function Apply-TemplateMetadata {
    param([string]$TemplateName)
    
    if ($TemplateMetadata.ContainsKey($TemplateName)) {
        $metadata = $TemplateMetadata[$TemplateName]
        Write-Info "Applying metadata to template: $TemplateName"
        
        try {
            $result = & coder templates edit $TemplateName `
                --display-name $metadata.DisplayName `
                --description $metadata.Description `
                --icon $metadata.Icon `
                --yes 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Metadata applied: display_name='$($metadata.DisplayName)', icon='$($metadata.Icon)'"
                return $true
            } else {
                Write-Warn "Failed to apply metadata to $TemplateName"
                Write-Host $result
                return $false
            }
        } catch {
            Write-Warn "Failed to apply metadata to $TemplateName : $_"
            return $false
        }
    } else {
        Write-Info "No metadata configured for template: $TemplateName"
        return $true
    }
}

# Check for Coder CLI authentication
# If parameters/environment variables are set, use them; otherwise assume CLI is pre-authenticated
if ([string]::IsNullOrEmpty($CoderUrl) -or [string]::IsNullOrEmpty($CoderToken)) {
    Write-Info "CODER_URL or CODER_SESSION_TOKEN not set, assuming Coder CLI is pre-authenticated"
    Write-Info "If not authenticated, run: coder login https://your-coder-instance.com"
} else {
    # Set environment variables for coder CLI
    $env:CODER_URL = $CoderUrl
    $env:CODER_SESSION_TOKEN = $CoderToken
}

# Check for coder CLI
try {
    $null = Get-Command coder -ErrorAction Stop
} catch {
    Write-Error "Coder CLI not found"
    Write-Host "  Install from: https://coder.com/docs/install/cli"
    Write-Host "  Or run: winget install Coder.Coder"
    exit 1
}

# Check for gh CLI
try {
    $null = Get-Command gh -ErrorAction Stop
} catch {
    Write-Error "GitHub CLI (gh) not found"
    Write-Host "  Install from: https://cli.github.com/"
    Write-Host "  Or run: winget install GitHub.cli"
    exit 1
}

# Create temporary directory
$WorkDir = Join-Path $env:TEMP "coder-deploy-$(Get-Random)"
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

try {
    Write-Info "Working directory: $WorkDir"

    # Fetch release information using gh CLI
    Write-Info "Fetching release info for: $GitHubRepo"

    try {
        if ($Prerelease) {
            # Get the latest pre-release
            Write-Info "Looking for latest pre-release..."
            $ReleasesJson = & gh release list --repo $GitHubRepo --limit 20 --json tagName,isPrerelease 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw $ReleasesJson
            }
            
            $Releases = $ReleasesJson | ConvertFrom-Json
            $LatestPrerelease = $Releases | Where-Object { $_.isPrerelease -eq $true } | Select-Object -First 1
            
            if (-not $LatestPrerelease) {
                Write-Error "No pre-release found in repository"
                Write-Host ""
                Write-Host "Possible causes:" -ForegroundColor Yellow
                Write-Host "  1. No pre-releases have been created yet"
                Write-Host "  2. No open pull requests with workflow runs"
                Write-Host ""
                Write-Host "To deploy the latest stable release instead:" -ForegroundColor Cyan
                Write-Host "  .\deploy-templates.ps1"
                exit 1
            }
            
            $Release = $LatestPrerelease.tagName
            Write-Info "Found pre-release: $Release"
            $ReleaseJson = & gh release view $Release --repo $GitHubRepo --json tagName,assets 2>&1
        }
        elseif ($Release -eq "latest") {
            $ReleaseJson = & gh release view --repo $GitHubRepo --json tagName,assets 2>&1
        } else {
            $ReleaseJson = & gh release view $Release --repo $GitHubRepo --json tagName,assets 2>&1
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw $ReleaseJson
        }
        
        $ReleaseInfo = $ReleaseJson | ConvertFrom-Json
    } catch {
        Write-Error "Failed to fetch release information"
        Write-Host ""
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "  1. No releases have been created yet"
        Write-Host "  2. Not authenticated with gh CLI (run: gh auth login)"
        Write-Host "  3. The repository name is incorrect"
        Write-Host ""
        Write-Host "To deploy from local source instead:" -ForegroundColor Cyan
        Write-Host "  coder templates push ai-dev --directory templates/ai-dev"
        exit 1
    }

    $ReleaseTag = $ReleaseInfo.tagName
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
            Write-Info "[DRY-RUN] Would download: $($Asset.name)"
            Write-Info "[DRY-RUN] Would push to Coder: $TemplateName"
            if ($TemplateMetadata.ContainsKey($TemplateName)) {
                $metadata = $TemplateMetadata[$TemplateName]
                Write-Info "[DRY-RUN] Would apply metadata: display_name='$($metadata.DisplayName)', icon='$($metadata.Icon)'"
            }
            $Deployed++
            continue
        }

        # Download the template zip using gh CLI
        $ZipFile = Join-Path $WorkDir "$TemplateName.zip"
        $TemplateDir = Join-Path $WorkDir $TemplateName

        Write-Info "Downloading: $($Asset.name)"
        try {
            $downloadResult = & gh release download $ReleaseTag --repo $GitHubRepo --pattern "$TemplateName.zip" --dir $WorkDir 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw $downloadResult
            }
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
                
                # Apply template metadata (display name, description, icon)
                Apply-TemplateMetadata -TemplateName $TemplateName
                
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
