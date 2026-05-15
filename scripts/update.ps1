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
$KitVersion = "1.15.0-rc1"

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
    Compare-And-Update (Join-Path $KitRoot "tooling\codex\hooks.json")  (Join-Path $Target ".codex\hooks.json")
    Update-Directory   (Join-Path $KitRoot "tooling\codex\hooks")       (Join-Path $Target ".codex\hooks")
    # Codex skills (5 subagents) merge into shared .agents/skills/
    Update-Directory   (Join-Path $KitRoot "tooling\codex\skills")      (Join-Path $Target ".agents\skills")

    # -- v1.14 migration: remove legacy .codex/agents/*.toml --------------
    # The Rust Codex CLI does not read this directory. Files are leftover from
    # pre-1.14 kit versions. Delete them so they don't sit stale in user repos.
    $legacyCodexAgents = Join-Path $Target ".codex\agents"
    if (Test-Path $legacyCodexAgents) {
        foreach ($legacy in @("architect", "code-reviewer", "codebase-investigator", "security-reviewer", "test-runner")) {
            $legacyFile = Join-Path $legacyCodexAgents "$legacy.toml"
            if (Test-Path $legacyFile) {
                $Changes.Add("REMOVED  .codex/agents/$legacy.toml (legacy)")
                if (-not $DryRun) {
                    Remove-Item $legacyFile -Force
                }
            }
        }
        # Remove the now-empty directory (only if empty - preserve user-added files).
        if (-not $DryRun) {
            $remaining = @(Get-ChildItem $legacyCodexAgents -Force -ErrorAction SilentlyContinue)
            if ($remaining.Count -eq 0) {
                Remove-Item $legacyCodexAgents -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# -- Update Claude tooling -------------------------------------------------
if ($ToolList -contains "claude") {
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\settings.json") (Join-Path $Target ".claude\settings.json")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\.mcp.json")          (Join-Path $Target ".mcp.json")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\.mcp.example.jsonc") (Join-Path $Target ".mcp.example.jsonc")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\agents")        (Join-Path $Target ".claude\agents")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\commands")      (Join-Path $Target ".claude\commands")
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
