<#
.SYNOPSIS
    Remove ai-agent-kit files from a target project.

.DESCRIPTION
    Removes (for each tool requested) only kit-installed files:
      - Root files: AGENTS.md, CLAUDE.md, GEMINI.md, .geminiignore.
      - Per-tool: settings.json, agents/ subdirectory, skills/ subdirectory.
      - Parent directories (.codex/, .claude/, .gemini/, .agents/) only if empty after removal.
      - .kit-version file (only if all installed tools are being removed).

    Preserves:
      - docs/ai/  (your project content - never touched)
      - Anything outside the kit layout.

.PARAMETER Target
    Path to the project root to uninstall from.

.PARAMETER Tools
    Comma-separated list of tools to remove. Default: read from .kit-version.

.PARAMETER DryRun
    Show what would be removed without writing anything.

.EXAMPLE
    .\uninstall.ps1 -Target "C:\Projects\my-project"
    .\uninstall.ps1 -Target "C:\Projects\my-project" -Tools "codex"
    .\uninstall.ps1 -Target "C:\Projects\my-project" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [string]$Tools = "",

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Target)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

# If no -Tools given, read from .kit-version.
if ([string]::IsNullOrWhiteSpace($Tools)) {
    $versionFile = Join-Path $Target ".kit-version"
    if (Test-Path $versionFile) {
        $versionLine = (Get-Content $versionFile -Raw).Trim()
        if ($versionLine -match "tools: (.+)") {
            $Tools = $Matches[1].Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($Tools)) {
        $Tools = "codex,claude,gemini"
    }
}

$ToolList = $Tools -split "," | ForEach-Object { $_.Trim().ToLower() }

$ValidTools = @("codex", "claude", "gemini")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, gemini"
    exit 1
}

# -- Helpers ---------------------------------------------------------------
function Step([string]$msg)    { Write-Host "`n> $msg" -ForegroundColor Cyan }
function Removed([string]$msg) { Write-Host "  [removed] $msg" -ForegroundColor Red }
function Absent([string]$msg)  { Write-Host "  [absent] $msg" -ForegroundColor Gray }
function DryRunOut([string]$msg) { Write-Host "  [would-remove] $msg" -ForegroundColor Yellow }

function Remove-KitPath([string]$path) {
    $rel = $path.Replace($Target, "").TrimStart("\", "/")
    if (Test-Path $path) {
        if ($DryRun) {
            DryRunOut $rel
        } else {
            Remove-Item -Path $path -Recurse -Force
            Removed $rel
        }
    } else {
        Absent $rel
    }
}

# -- Header ----------------------------------------------------------------
Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|       ai-agent-kit uninstaller       |"
Write-Host "+--------------------------------------+"
Write-Host "  Target: $Target"
Write-Host "  Tools : $($ToolList -join ', ')"
if ($DryRun) { Write-Host "  Mode  : DRY RUN (no files removed)" -ForegroundColor Yellow }
Write-Host ""
Write-Host "  NOTE: docs/ai/ is preserved. Remove it manually if you want a clean slate."

if ($ToolList -contains "codex") {
    Step "Removing Codex tooling"
    Remove-KitPath (Join-Path $Target "AGENTS.md")
    Remove-KitPath (Join-Path $Target ".codex\config.toml")
    Remove-KitPath (Join-Path $Target ".codex\agents")
    Remove-KitPath (Join-Path $Target ".agents\skills")
    # Clean up empty directories
    @(".codex", ".agents") | ForEach-Object {
        $d = Join-Path $Target $_
        if ((Test-Path $d) -and (Get-ChildItem -Path $d -Force | Measure-Object).Count -eq 0) {
            Remove-KitPath $d
        }
    }
}

if ($ToolList -contains "claude") {
    Step "Removing Claude Code tooling"
    Remove-KitPath (Join-Path $Target "CLAUDE.md")
    Remove-KitPath (Join-Path $Target ".claude\settings.json")
    Remove-KitPath (Join-Path $Target ".claude\agents")
    Remove-KitPath (Join-Path $Target ".claude\skills")
    # Clean up .claude/ only if nothing else is in it (preserves settings.local.json, hooks, etc.)
    $claudeDir = Join-Path $Target ".claude"
    if ((Test-Path $claudeDir) -and (Get-ChildItem -Path $claudeDir -Force | Measure-Object).Count -eq 0) {
        Remove-KitPath $claudeDir
    }
}

if ($ToolList -contains "gemini") {
    Step "Removing Gemini CLI tooling"
    Remove-KitPath (Join-Path $Target "GEMINI.md")
    Remove-KitPath (Join-Path $Target ".geminiignore")
    Remove-KitPath (Join-Path $Target ".gemini\settings.json")
    Remove-KitPath (Join-Path $Target ".gemini\agents")
    Remove-KitPath (Join-Path $Target ".gemini\skills")
    # Clean up empty .gemini/
    $geminiDir = Join-Path $Target ".gemini"
    if ((Test-Path $geminiDir) -and (Get-ChildItem -Path $geminiDir -Force | Measure-Object).Count -eq 0) {
        Remove-KitPath $geminiDir
    }
}

# Remove .kit-version only if ALL installed tools are being removed.
$versionFile = Join-Path $Target ".kit-version"
if (Test-Path $versionFile) {
    $versionLine = (Get-Content $versionFile -Raw).Trim()
    $installedRaw = "codex,claude,gemini"
    if ($versionLine -match "tools: (.+)") {
        $installedRaw = $Matches[1].Trim()
    }
    $installedList = $installedRaw -split "," | ForEach-Object { $_.Trim().ToLower() }
    $remaining = @($installedList | Where-Object { $ToolList -notcontains $_ })
    if ($remaining.Count -eq 0) {
        Step "Removing .kit-version"
        Remove-KitPath $versionFile
    } else {
        Step "Keeping .kit-version"
        Write-Host "  (some tools still installed: $($remaining -join ','))"
    }
}

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|         Uninstall complete           |"
Write-Host "+--------------------------------------+"
