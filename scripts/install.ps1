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
    Comma-separated list of tools to configure. Options: codex, claude, agy.
    Default: all three.

.PARAMETER Audit
    Optional anonymized audit setup mode. Options: disabled, prompt, official.
    Default: disabled.

.EXAMPLE
    .\install.ps1 -Target "C:\Projects\my-project"
    .\install.ps1 -Target "C:\Projects\my-project" -Tools "codex,claude"
    .\install.ps1 -Target "C:\Projects\my-project" -Audit official
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [string]$Tools = "codex,claude,agy",

    [ValidateSet("disabled", "prompt", "official")]
    [string]$Audit = "disabled",

    [string]$AuditConfig = ""
)
if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }  # AAK_DEBUG: opt-in trace (#305)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Paths -----------------------------------------------------------------
$KitRoot    = Split-Path -Parent $PSScriptRoot
$VersionFile = Join-Path $KitRoot "VERSION"
if (-not (Test-Path -LiteralPath $VersionFile -PathType Leaf)) {
    Write-Error "VERSION file not found at $VersionFile"
    exit 1
}
$KitVersion = (Get-Content -LiteralPath $VersionFile -Raw) -replace "`r", ""
if ($KitVersion.EndsWith("`n")) {
    $KitVersion = $KitVersion.Substring(0, $KitVersion.Length - 1)
}
if ($KitVersion -notmatch "^\d+\.\d+\.\d+$") {
    Write-Error "VERSION must contain a single semver value, got '$KitVersion'"
    exit 1
}
$ToolList   = @($Tools -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

# Kit-managed rel paths (forward-slashed, for cross-shell manifest parity with
# bash install.sh — a Windows install followed by a Git-Bash update on the same
# project must read the same paths).
$Managed = [System.Collections.Generic.List[string]]::new()
# "<added|updated|skipped> <rel>" per touched path, for the install audit (#313).
$RecordActions = [System.Collections.Generic.List[string]]::new()

function Get-OwningTool([string]$rel) {
    # Returns codex|claude|agy or "" for non-kit paths (docs/ai/,
    # .kit-version, .kit-manifest, .mcp.json, user files) — those are never
    # tracked in the manifest. `.mcp.json` is initialized by install and then
    # owned by the project; `.mcp.example.jsonc` is the versioned reference.
    switch -Wildcard ($rel) {
        "AGENTS.md"          { return "codex" }
        ".codex/*"           { return "codex" }
        ".agents/skills/*"   { return "codex" }
        ".ai-agent-kit/audit/*" { return "shared" }
        ".ai-agent-kit/delegate/*" { return "shared" }
        "CLAUDE.md"          { return "claude" }
        ".mcp.example.jsonc" { return "claude" }
        ".claude/*"          { return "claude" }
        "AGY.md"          { return "agy" }
        ".agyignore"      { return "agy" }
        ".agy/*"          { return "agy" }
        default              { return "" }
    }
}

function Write-Utf8NoBom([string]$path, [string]$text) {
    # PowerShell 5.1 Set-Content -Encoding utf8 writes a BOM. The manifest is
    # parsed line-by-line by bash update.sh, where a BOM on the first line
    # breaks the entry. UTF-8 *without* BOM keeps it cross-shell readable.
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

$ValidTools = @("codex", "claude", "agy")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, agy"
    exit 1
}
if ($ToolList.Count -eq 0) {
    Write-Error "Unknown tool(s): (empty). Valid options: codex, claude, agy"
    exit 1
}
$ManifestScope = @($ToolList + @("shared"))

# -- Helpers ---------------------------------------------------------------
function Write-Step([string]$msg) {
    Write-Host "`n> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "  [ok] $msg" -ForegroundColor Green
}

function Write-Preserve([string]$msg) {
    Write-Host "  [skip] $msg (project content - preserved)" -ForegroundColor Yellow
    $RecordActions.Add("skipped $msg")
}

# Append one NDJSON line describing what this lifecycle run changed (#313).
# Local, parseable record under .ai-agent-kit/; never pushed and not tracked
# in .kit-manifest. Built manually so the line matches the bash writer exactly.
function Write-LifecycleAudit([string]$lifecycle) {
    $recordDir = Join-Path $Target ".ai-agent-kit"
    [System.IO.Directory]::CreateDirectory($recordDir) | Out-Null
    $recordFile = Join-Path $recordDir "install-audit.ndjson"
    $added = 0; $updated = 0; $pruned = 0; $skipped = 0
    $changeParts = @()
    foreach ($entry in $RecordActions) {
        $sp = $entry.IndexOf(" ")
        $action = $entry.Substring(0, $sp)
        $rel = $entry.Substring($sp + 1)
        switch ($action) {
            "added"   { $added++ }
            "updated" { $updated++ }
            "pruned"  { $pruned++ }
            "skipped" { $skipped++ }
        }
        $changeParts += '{"path":"' + $rel + '","action":"' + $action + '"}'
    }
    $changes = $changeParts -join ","
    $ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
    $line = '{"schema_version":"0.1.0","kit_version":"' + $KitVersion + '","action":"' + $lifecycle +
            '","occurred_at":"' + $ts + '","changes":[' + $changes + '],"summary":{"added":' + $added +
            ',"updated":' + $updated + ',"pruned":' + $pruned + ',"skipped":' + $skipped + '}}'
    [System.IO.File]::AppendAllText($recordFile, $line + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok ".ai-agent-kit/install-audit.ndjson (${lifecycle}: +$added ~$updated -$pruned =$skipped)"
    if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") {
        Write-Host "  [debug] lifecycle audit appended to $recordFile" -ForegroundColor DarkGray
    }
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
    $action = if (Test-Path -LiteralPath $dst) { "updated" } else { "added" }
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
    $RecordActions.Add("$action $rel")
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

function Get-AuditConfigPath {
    if (-not [string]::IsNullOrWhiteSpace($AuditConfig)) {
        return $AuditConfig
    }
    $homeDir = [Environment]::GetFolderPath("UserProfile")
    if ([string]::IsNullOrWhiteSpace($homeDir)) {
        $homeDir = $env:USERPROFILE
    }
    if ([string]::IsNullOrWhiteSpace($homeDir)) {
        $homeDir = $env:HOME
    }
    return (Join-Path $homeDir ".ai-agent-kit\config.json")
}

function Initialize-AuditConfig([string]$mode) {
    if ($mode -eq "disabled") {
        Write-Host "  [skip] anonymized audit remains disabled by default" -ForegroundColor Yellow
        return
    }

    if ($mode -eq "prompt") {
        $answer = Read-Host "Enable anonymized central audit metadata? This stores counters only, no prompts/responses/paths. Type 'yes' to enable"
        if ($answer -ne "yes") {
            Write-Host "  [skip] anonymized audit not enabled" -ForegroundColor Yellow
            return
        }
    }

    $configPath = Get-AuditConfigPath
    $configDir = Split-Path -Parent $configPath
    if (-not (Test-Path -LiteralPath $configDir)) {
        [System.IO.Directory]::CreateDirectory($configDir) | Out-Null
    }
    $homeDir = Split-Path -Parent $configDir
    $runtimePath = Join-Path $configDir "audit-runtime"
    $centralRepoPath = Join-Path $configDir "central-audit"
    [System.IO.Directory]::CreateDirectory($runtimePath) | Out-Null

    $config = [ordered]@{
        schema_version = "0.1.0"
        audit = [ordered]@{
            enabled = $true
            mode = "official-central-repo"
            official_remote_url = "https://github.com/PetrovC/ai-agent-kit.git"
            branch = "agent-audit-data"
            runtime_path = $runtimePath
            central_repo_path = $centralRepoPath
            source_project_write_policy = "never"
            anonymization = [ordered]@{
                salt_scope = "local-only"
                drop_raw_content = $true
                forbid_exact_paths = $true
                forbid_repository_urls = $true
                forbid_branch_names = $true
            }
            push = [ordered]@{
                mode = "disabled"
                commit = $false
                unauthorized_fallback = "local-outbox"
            }
        }
    }
    $json = ($config | ConvertTo-Json -Depth 10)
    Write-Utf8NoBom $configPath ($json + "`n")
    Write-Ok "global audit config -> $configPath"
    Write-Host "  Audit data/runtime paths are outside the target project." -ForegroundColor Cyan
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
Write-Host "  Audit  : $Audit"

# -- Skills ----------------------------------------------------------------
if ($ToolList -contains "codex") {
    Write-Step "Installing skills -> .agents/skills/"
    Copy-KitDirectory (Join-Path $KitRoot "skills") (Join-Path $Target ".agents\skills")
}

if ($ToolList -contains "claude") {
    Write-Step "Installing skills -> .claude/skills/"
    Copy-KitDirectory (Join-Path $KitRoot "skills") (Join-Path $Target ".claude\skills")
}

if ($ToolList -contains "agy") {
    Write-Step "Installing skills -> .agy/skills/"
    Copy-KitDirectory (Join-Path $KitRoot "skills") (Join-Path $Target ".agy\skills")
}

# -- Codex -----------------------------------------------------------------
if ($ToolList -contains "codex") {
    Write-Step "Installing Codex tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\codex\AGENTS.md")   (Join-Path $Target "AGENTS.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\codex\config.toml") (Join-Path $Target ".codex\config.toml")
    Copy-KitFile (Join-Path $KitRoot "tooling\codex\hooks.windows.json") (Join-Path $Target ".codex\hooks.json")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\codex\hooks")  (Join-Path $Target ".codex\hooks")
    # Codex-specific skills (the 5 subagents) merge into the shared .agents/skills/
    # directory alongside the tool-agnostic skills already installed above.
    Copy-KitDirectory (Join-Path $KitRoot "tooling\codex\skills") (Join-Path $Target ".agents\skills")
}

# -- Claude ----------------------------------------------------------------
if ($ToolList -contains "claude") {
    Write-Step "Installing Claude Code tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\claude\settings.windows.json") (Join-Path $Target ".claude\settings.json")
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

# -- Antigravity ----------------------------------------------------------------
if ($ToolList -contains "agy") {
    Write-Step "Installing Antigravity CLI tooling"
    Copy-KitFile (Join-Path $KitRoot "tooling\agy\AGY.md")     (Join-Path $Target "AGY.md")
    Copy-KitFile (Join-Path $KitRoot "tooling\agy\.agyignore") (Join-Path $Target ".agyignore")
    Copy-KitFile (Join-Path $KitRoot "tooling\agy\settings.windows.json") (Join-Path $Target ".agy\settings.json")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\agy\agents")   (Join-Path $Target ".agy\agents")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\agy\commands") (Join-Path $Target ".agy\commands")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\agy\hooks")    (Join-Path $Target ".agy\hooks")
    Copy-KitDirectory (Join-Path $KitRoot "tooling\agy\policies") (Join-Path $Target ".agy\policies")
}

# -- Shared audit runtime --------------------------------------------------
Write-Step "Installing shared audit runtime -> .ai-agent-kit/audit/"
Copy-KitDirectory (Join-Path $KitRoot "tooling\shared\agent-audit") (Join-Path $Target ".ai-agent-kit\audit")

# -- Shared cross-tool delegation adapter ----------------------------------
Write-Step "Installing shared delegation adapter -> .ai-agent-kit/delegate/"
Copy-KitDirectory (Join-Path $KitRoot "tooling\shared\delegate") (Join-Path $Target ".ai-agent-kit\delegate")

# -- Optional global audit config -----------------------------------------
Write-Step "Anonymized audit setup"
Initialize-AuditConfig $Audit

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
# A partial install (`-Tools agy` on top of a codex+claude install) must
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
# FullTools = union(installed_old, -Tools) in canonical codex,claude,agy order.
$oldList = @()
if ($installedToolsOld) {
    $oldList = @($installedToolsOld -split "," | ForEach-Object { $_.Trim().ToLower() })
}
$fullTools = @()
foreach ($ref in @("codex", "claude", "agy")) {
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
        if ($ManifestScope -notcontains $otool) {
            $manifestKeepFromOld += $p
        }
    }
}
$newEntries = @($Managed | Where-Object { (Get-OwningTool $_) })
$manifestEntries = (@() + $newEntries + $manifestKeepFromOld) | Sort-Object -Unique | Where-Object { $_ }
Write-Utf8NoBom (Join-Path $Target ".kit-manifest") (($manifestEntries -join "`n") + "`n")
Write-Ok ".kit-manifest"

# -- Install audit record (#313) -------------------------------------------
Write-Step "Recording install audit -> .ai-agent-kit/install-audit.ndjson"
Write-LifecycleAudit "install"

# -- .gitignore hint -------------------------------------------------------
# Order matters: `.env.*` is a deny pattern that catches `.env.example` too,
# so the `!.env.example` / `!.env.*.example` whitelist entries MUST follow it.
# `.claude/session-log/` is the PreCompact snapshot dir written by session-summary.sh.
$recommendedGitignore = @(
    ".claude/settings.local.json",
    ".claude/session-log/",
    ".ai-agent-kit/install-audit.ndjson",
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
if ($env:OS -eq "Windows_NT") {
    $gitBashCandidates = @()
    if ($env:ProgramFiles) {
        $gitBashCandidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe")
        $gitBashCandidates += (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe")
    }
    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    if ($programFilesX86) {
        $gitBashCandidates += (Join-Path $programFilesX86 "Git\bin\bash.exe")
        $gitBashCandidates += (Join-Path $programFilesX86 "Git\usr\bin\bash.exe")
    }
    $gitBash = $gitBashCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $bashSource = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $gitBash -and -not $bashSource) {
        Write-Step "Windows: Git Bash not found"
        Write-Host "  ! The installed Claude / Codex hook wrapper needs Git Bash." -ForegroundColor Yellow
        Write-Host "  ! Install Git for Windows: https://git-scm.com/download/win" -ForegroundColor Yellow
    } elseif (-not $gitBash -and $bashSource.Source -like "*System32\bash.exe") {
        Write-Step "Windows: `bash` resolves to the WSL launcher stub"
        Write-Host "  ! $($bashSource.Source) is the WSL launcher. If no WSL distro is" -ForegroundColor Yellow
        Write-Host "  ! installed the hook wrapper cannot use it reliably." -ForegroundColor Yellow
        Write-Host "  ! Install Git for Windows or put Git Bash before C:\Windows\System32 on PATH." -ForegroundColor Yellow
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
Write-Host "  Note: update.ps1 refreshes managed kit files (CLAUDE.md, AGENTS.md, AGY.md,"
Write-Host "        skills/, hooks/, settings.json, ...) byte-compared against the kit source."
Write-Host "        Local edits to those files WILL be overwritten when they differ."
Write-Host "        docs/ai/ and .mcp.json are project-owned and never touched."
