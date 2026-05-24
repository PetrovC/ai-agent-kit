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
$KitVersion = "1.19.37"
$ToolList   = $Tools -split "," | ForEach-Object { $_.Trim().ToLower() }

# Kit-managed rel paths (forward-slashed, for cross-shell manifest parity with
# bash install.sh — a Windows install followed by a Git-Bash update on the same
# project must read the same paths).
$Managed = [System.Collections.Generic.List[string]]::new()

function Get-OwningTool([string]$rel) {
    # Returns codex|claude|gemini or "" for non-kit paths (docs/ai/,
    # .kit-version, .kit-manifest, .mcp.json, user files) — those are never
    # tracked in the manifest. `.mcp.json` is initialized by install and then
    # owned by the project; `.mcp.example.jsonc` is the versioned reference.
    switch -Wildcard ($rel) {
        "AGENTS.md"          { return "codex" }
        ".codex/*"           { return "codex" }
        ".agents/skills/*"   { return "codex" }
        "CLAUDE.md"          { return "claude" }
        ".mcp.example.jsonc" { return "claude" }
        ".claude/*"          { return "claude" }
        "GEMINI.md"          { return "gemini" }
        ".geminiignore"      { return "gemini" }
        ".gemini/*"          { return "gemini" }
        default              { return "" }
    }
}

function Write-Utf8NoBom([string]$path, [string]$text) {
    # PowerShell 5.1 Set-Content -Encoding utf8 writes a BOM. The manifest is
    # parsed line-by-line by bash update.sh, where a BOM on the first line
    # breaks the entry. UTF-8 *without* BOM keeps it cross-shell readable.
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

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
    if (-not (Test-Path -LiteralPath $dstDir)) {
        # `New-Item -Path $dstDir` would treat wildcard chars in $dstDir
        # (`[`, `]`, `*`, `?`) as glob patterns and either error out or
        # create the wrong path. [System.IO.Directory]::CreateDirectory
        # takes its argument as a literal filesystem path and creates all
        # intermediate directories — no wildcard interpretation, no
        # cmdlet-parameter rule churn.
        [System.IO.Directory]::CreateDirectory($dstDir) | Out-Null
    }
    # PowerShell's Copy-Item has -LiteralPath for SOURCE only; -Destination
    # still interprets wildcards, so a bracketed dst like
    # `C:\…\[acme]\.codex\config.toml` would fail or copy to the wrong
    # path. [System.IO.File]::Copy is literal on both sides.
    [System.IO.File]::Copy($src, $dst, $true)
    # Closes #74: `.Replace($Target, "")` strips EVERY literal occurrence
    # of $Target from $dst, so `-Target .` collapses every dot — including
    # the dot prefix of `.codex/`, `.claude/`, and every file extension —
    # producing nonsense like `codex/configtoml`. Use a true prefix strip
    # so only the literal $Target prefix is removed.
    if ($dst.StartsWith($Target)) {
        $rel = $dst.Substring($Target.Length)
    } else {
        $rel = $dst
    }
    $rel = $rel.TrimStart("\", "/").Replace("\", "/")
    $Managed.Add($rel)
    Write-Ok $rel
}

function Copy-KitDirectory([string]$srcDir, [string]$dstDir) {
    # Closes #89: every Test-Path / Copy-Item / Get-ChildItem on a path
    # derived from $Target uses -LiteralPath so Windows paths containing
    # wildcard chars (`[`, `]`, `*`, `?`) — common in client folders like
    # `C:\work\[acme]\app` — are treated as literal filesystem paths, not
    # glob patterns.
    if (-not (Test-Path -LiteralPath $srcDir)) { return }
    Get-ChildItem -LiteralPath $srcDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($srcDir.Length).TrimStart("\", "/")
        $dst      = Join-Path $dstDir $relative
        Copy-KitFile $_.FullName $dst
    }
}

# -- Validate target -------------------------------------------------------
# -LiteralPath: treat $Target as a literal string, not a wildcard pattern
# (so brackets / glob chars in paths are not silently expanded).
# -PathType Container: a regular file passes Test-Path but is not a project
# root — Join-Path would then produce bogus "<file>\AGENTS.md" destinations
# and copies would either fail mid-run or write outside the intended tree.
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
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
    Copy-KitFile (Join-Path $KitRoot "tooling\codex\hooks.json")  (Join-Path $Target ".codex\hooks.json")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\codex\hooks")  (Join-Path $Target ".codex\hooks")
    # Codex-specific skills (the 5 subagents) merge into the shared .agents/skills/
    # directory alongside the tool-agnostic skills already installed above.
    Copy-KitDirectory (Join-Path $KitRoot "tooling\codex\skills") (Join-Path $Target ".agents\skills")
}

# -- Claude ----------------------------------------------------------------
if ($ToolList -contains "claude") {
    Write-Step "Installing Claude Code tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\settings.json") (Join-Path $Target ".claude\settings.json")
    # .mcp.json is initialized once and then OWNED BY THE PROJECT — install
    # bootstraps an empty file only when missing, update never overwrites it.
    # The versioned reference users copy server blocks from is .mcp.example.jsonc.
    $mcpJsonDst = Join-Path $Target ".mcp.json"
    if (Test-Path -LiteralPath $mcpJsonDst) {
        Write-Preserve ".mcp.json"
    } else {
        # See Copy-KitFile comment: Copy-Item -Destination interprets
        # wildcards, so use the .NET API for a literal dst path.
        [System.IO.File]::Copy((Join-Path $KitRoot "tooling\claude\.mcp.json"), $mcpJsonDst, $true)
        Write-Ok ".mcp.json"
    }
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\.mcp.example.jsonc") (Join-Path $Target ".mcp.example.jsonc")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\claude\agents")   (Join-Path $Target ".claude\agents")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\claude\commands") (Join-Path $Target ".claude\commands")
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
    Copy-KitDirectory (Join-Path $KitRoot "tooling\gemini\commands") (Join-Path $Target ".gemini\commands")
}

# -- Project template (docs/ai/) - preserved if it exists ------------------
Write-Step "Installing project template -> docs/ai/"

$docsAiDir = Join-Path $Target "docs\ai"

Get-ChildItem -LiteralPath (Join-Path $KitRoot "project-template") -File | ForEach-Object {
    $dst = Join-Path $docsAiDir $_.Name
    if (Test-Path -LiteralPath $dst) {
        Write-Preserve "docs/ai/$($_.Name)"
    } else {
        Copy-KitFile $_.FullName $dst
    }
}

# -- .kit-version + .kit-manifest ------------------------------------------
# A partial install (`-Tools gemini` on top of a codex+claude install) must
# UNION its -Tools with the already-installed set in .kit-version, never
# shrink it; and must MERGE the new manifest entries with the manifest
# entries of tools NOT in this run, never overwrite them.
Write-Step "Writing .kit-version + .kit-manifest"

# Read the prior installed-tool set so we can preserve it across a partial run.
$installedToolsOld = ""
$versionFileOld = Join-Path $Target ".kit-version"
if (Test-Path -LiteralPath $versionFileOld) {
    $vl = (Get-Content -LiteralPath $versionFileOld -Raw).Trim()
    if ($vl -match "tools: ([^\s]+)") {
        $installedToolsOld = $Matches[1]
    }
}
# FullTools = union(installed_old, -Tools) in canonical codex,claude,gemini order.
$oldList = @()
if ($installedToolsOld) {
    $oldList = @($installedToolsOld -split "," | ForEach-Object { $_.Trim().ToLower() })
}
$fullTools = @()
foreach ($ref in @("codex", "claude", "gemini")) {
    if (($oldList -contains $ref) -or ($ToolList -contains $ref)) {
        $fullTools += $ref
    }
}
$fullToolsStr = $fullTools -join ","
$stamp = "ai-agent-kit@$KitVersion - installed $(Get-Date -Format 'yyyy-MM-dd') - tools: $fullToolsStr"
Write-Utf8NoBom (Join-Path $Target ".kit-version") $stamp
Write-Ok ".kit-version (tools: $fullToolsStr)"

# Manifest merge: keep entries from the old .kit-manifest whose owning tool
# is NOT in this run's -Tools, plus the entries we just installed. Mirrors
# update.ps1's KeepFromOld semantics so a partial install + a later update
# don't lose other tools' files.
$manifestKeepFromOld = @()
$manifestFileOld = Join-Path $Target ".kit-manifest"
if (Test-Path -LiteralPath $manifestFileOld) {
    foreach ($line in (Get-Content -LiteralPath $manifestFileOld)) {
        $p = $line.Trim()
        if (-not $p) { continue }
        $otool = Get-OwningTool $p
        if (-not $otool) { continue }
        if ($ToolList -notcontains $otool) {
            $manifestKeepFromOld += $p
        }
    }
}
$newEntries = @($Managed | Where-Object { (Get-OwningTool $_) })
$manifestEntries = (@() + $newEntries + $manifestKeepFromOld) | Sort-Object -Unique | Where-Object { $_ }
Write-Utf8NoBom (Join-Path $Target ".kit-manifest") (($manifestEntries -join "`n") + "`n")
Write-Ok ".kit-manifest"

# -- .gitignore hint -------------------------------------------------------
# Order matters: `.env.*` is a deny pattern that catches `.env.example` too,
# so the `!.env.example` / `!.env.*.example` whitelist entries MUST follow it.
# `.claude/session-log/` is the PreCompact snapshot dir written by session-summary.sh.
$recommendedGitignore = @(
    ".claude/settings.local.json",
    ".claude/session-log/",
    "CLAUDE.local.md",
    ".env",
    ".env.*",
    "!.env.example",
    "!.env.*.example"
)
$gitignore = Join-Path $Target ".gitignore"
if (Test-Path -LiteralPath $gitignore) {
    $content = Get-Content -LiteralPath $gitignore -Raw
    $missing = $recommendedGitignore | Where-Object { $content -notmatch [regex]::Escape($_) }
    if ($missing.Count -gt 0) {
        Write-Step ".gitignore - add these entries if not already present:"
        $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
} else {
    Write-Step ".gitignore not found - create it with at least:"
    $recommendedGitignore | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

# -- Windows: warn if `bash` is the WSL stub instead of Git Bash ----------
# Closes #42: the installed Claude / Codex hooks invoke `bash` (e.g.
# `bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-bash-guard.sh"`). On
# Windows, that name can resolve to %SystemRoot%\System32\bash.exe (the
# WSL launcher) — without an installed WSL distro the launcher exits
# non-zero on every hook invocation, and the PreToolUse guard silently
# never runs. Detect the resolution at install time so the user fixes
# PATH *before* the kit's only mechanical destructive-command block goes
# missing-in-action.
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $bashSource = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashSource) {
        Write-Step "Windows: bash not found on PATH"
        Write-Host "  ! The kit's Claude / Codex hooks need Git Bash on PATH." -ForegroundColor Yellow
        Write-Host "  ! Install Git for Windows (https://git-scm.com/download/win) and ensure" -ForegroundColor Yellow
        Write-Host "  ! C:\Program Files\Git\bin precedes C:\Windows\System32 on PATH." -ForegroundColor Yellow
    } elseif ($bashSource.Source -like "*System32\bash.exe") {
        Write-Step "Windows: `bash` resolves to the WSL launcher stub"
        Write-Host "  ! $($bashSource.Source) is the WSL launcher. If no WSL distro is" -ForegroundColor Yellow
        Write-Host "  ! installed the kit's PreToolUse hook (pre-bash-guard) will silently" -ForegroundColor Yellow
        Write-Host "  ! never run, losing the only mechanical block on destructive shell commands." -ForegroundColor Yellow
        Write-Host "  ! Put Git Bash (C:\Program Files\Git\bin) BEFORE C:\Windows\System32 on PATH" -ForegroundColor Yellow
        Write-Host "  ! and verify with: where bash; bash --version" -ForegroundColor Yellow
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
Write-Host "  5. Commit everything except local/runtime files (.claude/settings.local.json, .claude/session-log/, CLAUDE.local.md) and secrets"
Write-Host ""
Write-Host "Starter prompts (open in the kit, paste into your agent):"
Write-Host "  prompts/daily-ticket.md     <- start a GitHub issue"
Write-Host "  prompts/feature-planning.md <- plan a multi-file feature"
Write-Host "  prompts/bug-fix.md          <- reproduce and fix a bug"
Write-Host "  prompts/code-review.md      <- triage-style PR review"
Write-Host "  prompts/security-audit.md   <- targeted security pass"
Write-Host ""
Write-Host "To refresh kit-managed files while preserving docs/ai/ and .mcp.json:"
Write-Host "  .\scripts\update.ps1 -Target `"$Target`""
Write-Host ""
Write-Host "  Note: update.ps1 refreshes managed kit files (CLAUDE.md, AGENTS.md, GEMINI.md,"
Write-Host "        skills/, hooks/, settings.json, ...) byte-compared against the kit source."
Write-Host "        Local edits to those files WILL be overwritten when they differ."
Write-Host "        docs/ai/ and .mcp.json are project-owned and never touched."
