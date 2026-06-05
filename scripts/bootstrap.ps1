<#
.SYNOPSIS
    Download and install ai-agent-kit from a GitHub release.

.DESCRIPTION
    Quick install (all 3 tools, current directory):
      irm https://github.com/PetrovC/ai-agent-kit/releases/latest/download/bootstrap.ps1 | iex

    With explicit options (recommended — keeps your terminal history auditable):
      & ([scriptblock]::Create((irm 'https://github.com/PetrovC/ai-agent-kit/releases/latest/download/bootstrap.ps1'))) `
          -Target '.\myapp' -Tools 'claude,codex,agy' -Version 'v1.21.0'

.PARAMETER Version
    Release tag, e.g. v1.21.0. Default: fetch latest from GitHub API.

.PARAMETER Target
    Project directory to install into. Default: current directory.

.PARAMETER Tools
    Comma-separated list of tools: codex, claude, agy. Default: codex,claude,agy.

.PARAMETER Profile
    Installation profile: full or minimal. Default: full.

.PARAMETER DryRun
    Print what would happen; do not download or install.

.EXAMPLE
    irm https://github.com/PetrovC/ai-agent-kit/releases/latest/download/bootstrap.ps1 | iex

.EXAMPLE
    & ([scriptblock]::Create((irm 'https://github.com/PetrovC/ai-agent-kit/releases/latest/download/bootstrap.ps1'))) -Target '.\myapp' -Tools 'claude'
#>
param(
    [string]$Version = "",
    [string]$Target  = ".",
    [string]$Tools   = "codex,claude,agy",
    [ValidateSet("full", "minimal")]
    [string]$Profile = "full",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$Repo = "PetrovC/ai-agent-kit"

if (-not $Version) {
    Write-Host "Fetching latest release version..."
    $LatestRelease = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $Version = $LatestRelease.tag_name
    if (-not $Version) {
        Write-Error "Could not determine latest release version. Pass -Version v<tag> explicitly."
        exit 1
    }
}

$ArchiveName = "ai-agent-kit-${Version}.zip"
$ArchiveUrl  = "https://github.com/$Repo/releases/download/$Version/$ArchiveName"

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|      ai-agent-kit bootstrap         |"
Write-Host "+--------------------------------------+"
Write-Host "  Version: $Version"
Write-Host "  Target : $Target"
Write-Host "  Tools  : $Tools"
Write-Host "  Profile: $Profile"
Write-Host "  Source : $ArchiveUrl"
Write-Host ""

if ($DryRun) {
    Write-Host "[dry-run] Would download: $ArchiveUrl"
    Write-Host "[dry-run] Would extract to a temporary directory"
    Write-Host "[dry-run] Would run: install.ps1 -Target $Target -Tools $Tools -Profile $Profile"
    Write-Host "[dry-run] Would clean up the temporary directory"
    exit 0
}

if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

$TmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    $ZipPath = Join-Path $TmpDir $ArchiveName
    Write-Host "Downloading ${ArchiveName}..."
    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ZipPath -UseBasicParsing

    Write-Host "Extracting..."
    Expand-Archive -Path $ZipPath -DestinationPath $TmpDir -Force

    $InstallScript = Join-Path $TmpDir "install.ps1"
    if (-not (Test-Path -LiteralPath $InstallScript -PathType Leaf)) {
        Write-Error "install.ps1 not found in the release archive."
        exit 1
    }

    Write-Host "Running installer..."
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $InstallScript `
        -Target $Target -Tools $Tools -Profile $Profile
} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
