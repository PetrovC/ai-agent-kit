<#
.SYNOPSIS
    Install ai-agent-kit into a target project.

.DESCRIPTION
    Semantics:
      - Kit files (skills, tooling, agents, root .md) are ALWAYS overwritten.
        Re-running install gives you a clean baseline.
      - docs/ai/ is NEVER overwritten - it holds project-specific content filled by you.
        Delete docs/ai/ manually if you want a fresh template set.

    Use update.ps1 instead when you only want to refresh what changed.

.PARAMETER Target
    Path to the project root where the kit will be installed.

.PARAMETER Tools
    Comma-separated list of tools to configure. Options: codex, claude, gemini.
    Default: all three.

.EXAMPLE
    .\install.ps1 -Target "C:\Projects\my-project"
    .\install.ps1 -Target "C:\Projects\my-project" -Tools "codex,claude"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [string]$Tools = "codex,claude,gemini"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Paths -----------------------------------------------------------------
$KitRoot    = Split-Path -Parent $PSScriptRoot
$KitVersion = "1.11.0"
$ToolList   = $Tools -split "," | ForEach-Object { $_.Trim().ToLower() }

$ValidTools = @("codex", "claude", "gemini")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, gemini"
    exit 1
}

# -- Helpers ---------------------------------------------------------------
function Write-Step([string]$msg) {
    Write-Host "`n> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "  [ok] $msg" -ForegroundColor Green
}

function Write-Preserve([string]$msg) {
    Write-Host "  [skip] $msg (project content - preserved)" -ForegroundColor Yellow
}

function Copy-KitFile([string]$src, [string]$dst) {
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -Path $src -Destination $dst -Force
    $rel = $dst.Replace($Target, "").TrimStart("\", "/")
    Write-Ok $rel
}

function Copy-KitDirectory([string]$srcDir, [string]$dstDir) {
    if (-not (Test-Path $srcDir)) { return }
    Get-ChildItem -Path $srcDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($srcDir.Length).TrimStart("\", "/")
        $dst      = Join-Path $dstDir $relative
        Copy-KitFile $_.FullName $dst
    }
}

# -- Validate target -------------------------------------------------------
if (-not (Test-Path $Target)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

Write-Host "`n+--------------------------------------+" -ForegroundColor Magenta
Write-Host "|        ai-agent-kit installer        |" -ForegroundColor Magenta
Write-Host "+--------------------------------------+" -ForegroundColor Magenta
Write-Host "  Target : $Target"
Write-Host "  Tools  : $($ToolList -join ', ')"
Write-Host "  Version: $KitVersion"
Write-Host "  Mode   : OVERWRITE (kit files only; docs/ai/ preserved)" -ForegroundColor Yellow

# -- Skills ----------------------------------------------------------------
if ($ToolList -contains "codex") {
    Write-Step "Installing skills -> .agents/skills/"
    Copy-KitDirectory (Join-Path $KitRoot "skills") (Join-Path $Target ".agents\skills")
}

if ($ToolList -contains "claude") {
    Write-Step "Installing skills -> .claude/skills/"
    Copy-KitDirectory (Join-Path $KitRoot "skills") (Join-Path $Target ".claude\skills")
}

if ($ToolList -contains "gemini") {
    Write-Step "Installing skills -> .gemini/skills/"
    Copy-KitDirectory (Join-Path $KitRoot "skills") (Join-Path $Target ".gemini\skills")
}

# -- Codex -----------------------------------------------------------------
if ($ToolList -contains "codex") {
    Write-Step "Installing Codex tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\codex\AGENTS.md")   (Join-Path $Target "AGENTS.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\codex\config.toml") (Join-Path $Target ".codex\config.toml")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\codex\agents") (Join-Path $Target ".codex\agents")
}

# -- Claude ----------------------------------------------------------------
if ($ToolList -contains "claude") {
    Write-Step "Installing Claude Code tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\settings.json") (Join-Path $Target ".claude\settings.json")
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\.mcp.json")     (Join-Path $Target ".mcp.json")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\claude\agents")   (Join-Path $Target ".claude\agents")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\claude\hooks")    (Join-Path $Target ".claude\hooks")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\claude\rules")    (Join-Path $Target ".claude\rules")
}

# -- Gemini ----------------------------------------------------------------
if ($ToolList -contains "gemini") {
    Write-Step "Installing Gemini CLI tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\gemini\GEMINI.md")     (Join-Path $Target "GEMINI.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\gemini\.geminiignore") (Join-Path $Target ".geminiignore")
    Copy-KitFile (Join-Path $KitRoot "tooling\gemini\settings.json") (Join-Path $Target ".gemini\settings.json")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\gemini\agents")   (Join-Path $Target ".gemini\agents")
}

# -- Project template (docs/ai/) - preserved if it exists ------------------
Write-Step "Installing project template -> docs/ai/"

$docsAiDir = Join-Path $Target "docs\ai"

Get-ChildItem -Path (Join-Path $KitRoot "project-template") -File | ForEach-Object {
    $dst = Join-Path $docsAiDir $_.Name
    if (Test-Path $dst) {
        Write-Preserve "docs/ai/$($_.Name)"
    } else {
        Copy-KitFile $_.FullName $dst
    }
}

# -- .kit-version ----------------------------------------------------------
Write-Step "Writing .kit-version"
$stamp = "ai-agent-kit@$KitVersion - installed $(Get-Date -Format 'yyyy-MM-dd') - tools: $($ToolList -join ',')"
Set-Content -Path (Join-Path $Target ".kit-version") -Value $stamp -Encoding utf8
Write-Ok ".kit-version"

# -- .gitignore hint -------------------------------------------------------
$gitignore = Join-Path $Target ".gitignore"
if (Test-Path $gitignore) {
    $content = Get-Content $gitignore -Raw
    $entries = @(".claude/settings.local.json", "CLAUDE.local.md", ".env", ".env.*")
    $missing = $entries | Where-Object { $content -notmatch [regex]::Escape($_) }
    if ($missing.Count -gt 0) {
        Write-Step ".gitignore - add these entries if not already present:"
        $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
}

# -- Done ------------------------------------------------------------------
Write-Host "`n+--------------------------------------+" -ForegroundColor Green
Write-Host "|           Installation done!         |" -ForegroundColor Green
Write-Host "+--------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Fill in docs/ai/PROJECT.md      <- describe your product"
Write-Host "  2. Fill in docs/ai/COMMANDS.md     <- add your build/test commands"
Write-Host "  3. Fill in docs/ai/ARCHITECTURE.md"
Write-Host "  4. Run validate.ps1 to confirm all templates are filled"
Write-Host "  5. Commit everything (except .claude/settings.local.json and secrets)"
Write-Host ""
Write-Host "Starter prompts (open in the kit, paste into your agent):"
Write-Host "  prompts/daily-ticket.md     <- start a GitHub issue"
Write-Host "  prompts/feature-planning.md <- plan a multi-file feature"
Write-Host "  prompts/bug-fix.md          <- reproduce and fix a bug"
Write-Host "  prompts/code-review.md      <- triage-style PR review"
Write-Host "  prompts/security-audit.md   <- targeted security pass"
Write-Host ""
Write-Host "To pull in kit updates without overwriting your local edits:"
Write-Host "  .\scripts\update.ps1 -Target `"$Target`""
