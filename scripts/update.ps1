<#
.SYNOPSIS
    Update ai-agent-kit files in a target project.

.DESCRIPTION
    Shows a diff of what would change, then optionally overwrites kit files.
    Project docs (docs/ai/) are NEVER overwritten - they contain project-specific content.

.PARAMETER Target
    Path to the project root to update.

.PARAMETER Tools
    Comma-separated list of tools to update. Default: read from .kit-version if present.

.PARAMETER DryRun
    Show what would change without writing anything.

.EXAMPLE
    .\update.ps1 -Target "C:\Projects\my-project"
    .\update.ps1 -Target "C:\Projects\my-project" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [string]$Tools = "",

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$KitRoot    = Split-Path -Parent $PSScriptRoot
$KitVersion = "1.13.0"

# -- Read installed version ------------------------------------------------
$versionFile    = Join-Path $Target ".kit-version"
$installedTools = "codex,claude,gemini"
$installedVersion = $null

if (Test-Path $versionFile) {
    $versionLine = (Get-Content $versionFile -Raw).Trim()
    Write-Host "Installed: $versionLine"

    if ($versionLine -match "ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+)") {
        $installedVersion = $Matches[1]
    }
    if ($versionLine -match "tools: (.+)") {
        $installedTools = $Matches[1].Trim()
    }
} else {
    Write-Host "No .kit-version found - treating as fresh install."
}

# Warn on version drift
if ($installedVersion -and $installedVersion -ne $KitVersion) {
    Write-Host ""
    Write-Host "  WARNING: installed kit version ($installedVersion) differs from source ($KitVersion)." -ForegroundColor Yellow
    Write-Host "           Review the CHANGELOG before applying." -ForegroundColor Yellow
    Write-Host ""
}

if ([string]::IsNullOrWhiteSpace($Tools)) {
    $Tools = $installedTools
}

$ToolList = $Tools -split "," | ForEach-Object { $_.Trim().ToLower() }

$ValidTools = @("codex", "claude", "gemini")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, gemini"
    exit 1
}

Write-Host "Kit version: $KitVersion"
Write-Host "Target     : $Target"
Write-Host "Tools      : $($ToolList -join ', ')"
if ($DryRun) { Write-Host "Mode       : DRY RUN (no files written)" -ForegroundColor Yellow }

# -- Helpers ---------------------------------------------------------------
$Changes = [System.Collections.Generic.List[string]]::new()

function Compare-And-Update([string]$src, [string]$dst) {
    if (-not (Test-Path $src)) { return }

    $rel = $dst.Replace($Target, "").TrimStart("\", "/")

    if (-not (Test-Path $dst)) {
        $Changes.Add("NEW      $rel")
        if (-not $DryRun) {
            $dir = Split-Path -Parent $dst
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item $src $dst -Force
        }
        return
    }

    $srcHash = (Get-FileHash $src -Algorithm MD5).Hash
    $dstHash = (Get-FileHash $dst -Algorithm MD5).Hash

    if ($srcHash -ne $dstHash) {
        $Changes.Add("UPDATED  $rel")
        if (-not $DryRun) {
            Copy-Item $src $dst -Force
        }
    }
}

function Update-Directory([string]$srcDir, [string]$dstDir) {
    if (-not (Test-Path $srcDir)) { return }
    Get-ChildItem -Path $srcDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($srcDir.Length).TrimStart("\", "/")
        Compare-And-Update $_.FullName (Join-Path $dstDir $relative)
    }
}

# -- Update skills ---------------------------------------------------------
if ($ToolList -contains "codex")  { Update-Directory (Join-Path $KitRoot "skills") (Join-Path $Target ".agents\skills") }
if ($ToolList -contains "claude") { Update-Directory (Join-Path $KitRoot "skills") (Join-Path $Target ".claude\skills") }
if ($ToolList -contains "gemini") { Update-Directory (Join-Path $KitRoot "skills") (Join-Path $Target ".gemini\skills") }

# -- Update Codex tooling --------------------------------------------------
if ($ToolList -contains "codex") {
    Compare-And-Update (Join-Path $KitRoot "tooling\codex\AGENTS.md")   (Join-Path $Target "AGENTS.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\codex\config.toml") (Join-Path $Target ".codex\config.toml")
    Update-Directory   (Join-Path $KitRoot "tooling\codex\agents")      (Join-Path $Target ".codex\agents")
}

# -- Update Claude tooling -------------------------------------------------
if ($ToolList -contains "claude") {
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\settings.json") (Join-Path $Target ".claude\settings.json")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\.mcp.json")     (Join-Path $Target ".mcp.json")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\agents")        (Join-Path $Target ".claude\agents")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\hooks")         (Join-Path $Target ".claude\hooks")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\rules")         (Join-Path $Target ".claude\rules")
}

# -- Update Gemini tooling -------------------------------------------------
if ($ToolList -contains "gemini") {
    Compare-And-Update (Join-Path $KitRoot "tooling\gemini\GEMINI.md")      (Join-Path $Target "GEMINI.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\gemini\.geminiignore")  (Join-Path $Target ".geminiignore")
    Compare-And-Update (Join-Path $KitRoot "tooling\gemini\settings.json")  (Join-Path $Target ".gemini\settings.json")
    Update-Directory   (Join-Path $KitRoot "tooling\gemini\agents")         (Join-Path $Target ".gemini\agents")
}

# NOTE: docs/ai/ is intentionally NOT updated - it contains project-specific content.

# -- Update .kit-version ---------------------------------------------------
if (-not $DryRun) {
    $stamp = "ai-agent-kit@$KitVersion - updated $(Get-Date -Format 'yyyy-MM-dd') - tools: $($ToolList -join ',')"
    Set-Content -Path $versionFile -Value $stamp -Encoding utf8
}

# -- Report ----------------------------------------------------------------
Write-Host ""
if ($Changes.Count -eq 0) {
    Write-Host "Everything is up to date." -ForegroundColor Green
} else {
    Write-Host "Changes:" -ForegroundColor Cyan
    $Changes | ForEach-Object { Write-Host "  $_" }

    if ($DryRun) {
        Write-Host "`nRun without -DryRun to apply these changes." -ForegroundColor Yellow
    } else {
        Write-Host "`n$($Changes.Count) file(s) updated." -ForegroundColor Green
    }
}
