#
# OpenClaw (Clawbot) Docker Uninstaller - Windows PowerShell Version
# Removes OpenClaw installation from your system
#
# Usage:
#   irm https://raw.githubusercontent.com/phioranex/openclaw-docker/main/uninstall.ps1 | iex
#
# Or with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phioranex/openclaw-docker/main/uninstall.ps1))) -KeepData
#

param(
    [string]$InstallDir = "$env:USERPROFILE\openclaw",
    [switch]$KeepData,
    [switch]$KeepImage,
    [switch]$Force,
    [switch]$Help
)

# Config
$Image = "ghcr.io/phioranex/openclaw-docker:latest"

# Error handling
$ErrorActionPreference = "Stop"

# Functions
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "║    ____                    _____ _                           ║" -ForegroundColor Red
    Write-Host "║   / __ \                  / ____| |                          ║" -ForegroundColor Red
    Write-Host "║  | |  | |_ __   ___ _ __ | |    | | __ ___      __           ║" -ForegroundColor Red
    Write-Host "║  | |  | | '_ \ / _ \ '_ \| |    | |/ _`` \ \ /\ / /           ║" -ForegroundColor Red
    Write-Host "║  | |__| | |_) |  __/ | | | |____| | (_| |\ V  V /            ║" -ForegroundColor Red
    Write-Host "║   \____/| .__/ \___|_| |_|\_____|_|\__,_| \_/\_/             ║" -ForegroundColor Red
    Write-Host "║         | |                                                  ║" -ForegroundColor Red
    Write-Host "║         |_|                                                  ║" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "║            Docker Uninstaller by Phioranex                   ║" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Confirm-Action {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )
    
    if ($Force) {
        return $true
    }
    
    if ($Default -eq "y") {
        $PromptText = "$Prompt [Y/n] "
    } else {
        $PromptText = "$Prompt [y/N] "
    }
    
    while ($true) {
        Write-Host $PromptText -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        if ([string]::IsNullOrEmpty($response)) {
            $response = $Default
        }
        
        switch -Regex ($response) {
            '^[Yy]' { return $true }
            '^[Nn]' { return $false }
            default { Write-Host "Please answer yes or no." }
        }
    }
}

# Show help
if ($Help) {
    Write-Host "OpenClaw (Clawbot) Docker Uninstaller - Windows"
    Write-Host ""
    Write-Host "Usage: uninstall.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR   Installation directory (default: ~\openclaw)"
    Write-Host "  -KeepData         Keep configuration and workspace data"
    Write-Host "  -KeepImage        Keep Docker image"
    Write-Host "  -Force            Skip confirmation prompts"
    Write-Host "  -Help             Show this help message"
    return
}

# Main script
Write-Banner

Write-Host "This will uninstall OpenClaw from your system." -ForegroundColor Yellow
Write-Host ""

# Stop and remove containers
Write-Step "Stopping and removing containers..."

$ContainersRemoved = $false
try {
    $containers = docker ps -a --format "{{.Names}}" 2>$null
    
    if ($containers -match "openclaw-gateway") {
        docker stop openclaw-gateway 2>$null | Out-Null
        docker rm openclaw-gateway 2>$null | Out-Null
        Write-Success "Removed openclaw-gateway container"
        $ContainersRemoved = $true
    }
    
    if ($containers -match "openclaw-socat") {
        docker stop openclaw-socat 2>$null | Out-Null
        docker rm openclaw-socat 2>$null | Out-Null
        Write-Success "Removed openclaw-socat container"
        $ContainersRemoved = $true
    }
    
    if ($containers -match "openclaw-cli") {
        docker rm openclaw-cli 2>$null | Out-Null
        Write-Success "Removed openclaw-cli container"
        $ContainersRemoved = $true
    }
} catch {
    # Ignore errors
}

if (-not $ContainersRemoved) {
    Write-Warning "No OpenClaw containers found"
}

# Remove data directories
$ConfigDir = "$env:USERPROFILE\.openclaw"

if (-not $KeepData -and (Test-Path $ConfigDir)) {
    Write-Step "Data directories found at $ConfigDir"
    
    if (Confirm-Action "Remove configuration and workspace data? (This cannot be undone)") {
        Remove-Item -Path $ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Removed data directory: $ConfigDir"
    } else {
        Write-Warning "Keeping data directory: $ConfigDir"
    }
} elseif ($KeepData -and (Test-Path $ConfigDir)) {
    Write-Warning "Keeping data directory: $ConfigDir"
} elseif (-not (Test-Path $ConfigDir)) {
    Write-Warning "No data directory found at $ConfigDir"
}

# Remove Docker image
if (-not $KeepImage) {
    try {
        $images = docker images --format "{{.Repository}}:{{.Tag}}" 2>$null
        
        if ($images -match [regex]::Escape($Image)) {
            Write-Step "Docker image found: $Image"
            
            if (Confirm-Action "Remove Docker image? (You can re-download it later)") {
                try {
                    docker rmi $Image 2>$null | Out-Null
                    Write-Success "Removed Docker image"
                } catch {
                    Write-Warning "Could not remove image (may be in use)"
                }
            } else {
                Write-Warning "Keeping Docker image: $Image"
            }
        } else {
            Write-Warning "No Docker image found: $Image"
        }
    } catch {
        Write-Warning "Could not check for Docker image"
    }
} else {
    Write-Warning "Keeping Docker image: $Image"
}

# Remove installation directory
if (Test-Path $InstallDir) {
    Write-Step "Installation directory found at $InstallDir"
    
    if (Confirm-Action "Remove installation directory?") {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Removed installation directory: $InstallDir"
    } else {
        Write-Warning "Keeping installation directory: $InstallDir"
    }
} else {
    Write-Warning "No installation directory found at $InstallDir"
}

# Success message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║         OpenClaw has been uninstalled successfully! 👋        ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

if ($KeepData -or (Test-Path $ConfigDir)) {
    Write-Host ""
    Write-Host "Data preserved:" -ForegroundColor White
    Write-Host "  Config:         $ConfigDir" -ForegroundColor Cyan
    Write-Host "  Workspace:      $ConfigDir\workspace" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "To reinstall OpenClaw:" -ForegroundColor White
Write-Host "  irm https://raw.githubusercontent.com/phioranex/openclaw-docker/main/install.ps1 | iex" -ForegroundColor Cyan

Write-Host ""
Write-Host "Thank you for using OpenClaw! 🦞" -ForegroundColor Yellow
Write-Host ""
