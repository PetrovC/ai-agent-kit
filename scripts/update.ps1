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
if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }  # AAK_DEBUG: opt-in trace (#305)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Validate $Target before any I/O. Without this, a typo or a path that points
# at a file silently triggers the New-Item -ItemType Directory branches in
# Compare-And-Update and starts materializing a pseudo-install under an
# invalid root. Mirrors install.sh / update.sh which both refuse [[ ! -d ]].
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

$KitRoot    = Split-Path -Parent $PSScriptRoot
$VersionFileRoot = Join-Path $KitRoot "VERSION"
if (-not (Test-Path -LiteralPath $VersionFileRoot -PathType Leaf)) {
    Write-Error "VERSION file not found at $VersionFileRoot"
    exit 1
}
$KitVersion = (Get-Content -LiteralPath $VersionFileRoot -Raw) -replace "`r", ""
if ($KitVersion.EndsWith("`n")) {
    $KitVersion = $KitVersion.Substring(0, $KitVersion.Length - 1)
}
if ($KitVersion -notmatch "^\d+\.\d+\.\d+$") {
    Write-Error "VERSION must contain a single semver value, got '$KitVersion'"
    exit 1
}

function Get-OwningTool([string]$rel) {
    # Returns codex|claude|agy or "" for non-kit paths (docs/ai/,
    # .kit-version, .kit-manifest, .mcp.json, user files) — those are never
    # pruned and never written to the manifest. `.mcp.json` is initialized by
    # install and then owned by the project; `.mcp.example.jsonc` is the
    # versioned reference.
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

function Compare-Files([string]$a, [string]$b) {
    # Returns $true if identical. Length check first, then byte-stream compare
    # with early exit on the first differing byte — the cmp -s equivalent. We
    # do not hash both whole files (Get-FileHash) because that always reads
    # them fully even when they obviously differ.
    # Both args may live under a $Target containing wildcard chars
    # (`[`, `]`); use -LiteralPath so Get-Item doesn't expand them.
    if ((Get-Item -LiteralPath $a).Length -ne (Get-Item -LiteralPath $b).Length) { return $false }
    $sa = [System.IO.File]::OpenRead($a)
    $sb = [System.IO.File]::OpenRead($b)
    try {
        while ($true) {
            $ba = $sa.ReadByte()
            $bb = $sb.ReadByte()
            if ($ba -ne $bb) { return $false }
            if ($ba -eq -1)  { return $true }   # both EOF — lengths matched
        }
    } finally {
        $sa.Close(); $sb.Close()
    }
}

function Write-Utf8NoBom([string]$path, [string]$text) {
    # PowerShell 5.1 Set-Content -Encoding utf8 writes a BOM. The manifest is
    # parsed line-by-line by bash update.sh; a BOM on the first line breaks
    # the entry. UTF-8 *without* BOM keeps it cross-shell readable.
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# -- Read installed version ------------------------------------------------
$versionFile    = Join-Path $Target ".kit-version"
$manifestFile   = Join-Path $Target ".kit-manifest"
$installedTools = "codex,claude,agy"
$installedVersion = $null

if (Test-Path -LiteralPath $versionFile) {
    $versionLine = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    Write-Host "Installed: $versionLine"

    if ($versionLine -match "ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+)") {
        $installedVersion = $Matches[1]
    }
    if ($versionLine -match "tools: ([^\s]+)") {
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

$ToolList = @($Tools -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

$ValidTools = @("codex", "claude", "agy")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, agy"
    exit 1
}
$ManifestScope = @($ToolList + @("shared"))

Write-Host "Kit version: $KitVersion"
Write-Host "Target     : $Target"
Write-Host "Tools      : $($ToolList -join ', ')"
if ($DryRun) { Write-Host "Mode       : DRY RUN (no files written)" -ForegroundColor Yellow }

# -- Helpers ---------------------------------------------------------------
$Changes      = [System.Collections.Generic.List[string]]::new()
$Notes        = [System.Collections.Generic.List[string]]::new()
$Managed      = [System.Collections.Generic.List[string]]::new()   # touched this run (any tool in scope)
$KeepFromOld  = [System.Collections.Generic.List[string]]::new()   # old-manifest entries for tools NOT in this run
# "<added|updated|pruned|skipped> <rel>" per touched path, for the install audit (#313).
$RecordActions = [System.Collections.Generic.List[string]]::new()

# Append one NDJSON line describing what this lifecycle run changed (#313).
# Local, parseable record under .ai-agent-kit/; mirrors install.ps1 and the
# bash writers byte-for-byte in line format.
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
    if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") {
        Write-Host "  [debug] lifecycle audit appended to $recordFile" -ForegroundColor DarkGray
    }
}

function Test-ManifestEntry([string]$rel) {
    if (-not (Test-Path -LiteralPath $manifestFile)) { return $false }
    foreach ($line in Get-Content -LiteralPath $manifestFile) {
        if ($line.Trim() -eq $rel) { return $true }
    }
    return $false
}

function Compare-And-Update([string]$src, [string]$dst) {
    # Closes #68: every direct caller below is a REQUIRED kit source
    # (AGENTS.md, CLAUDE.md, settings.json, …). A silent `return` here
    # masked packaging accidents — a missing source produced
    # "Everything is up to date" while leaving the target out of sync with
    # the kit. Treat absence as a fatal release-safety error. Directories
    # walked via Update-Directory below are optional by nature and use a
    # separate `Test-Path $srcDir` guard.
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        Write-Error "Required kit source missing: $src (release packaging is incomplete; cannot continue)"
        exit 1
    }

    # Forward-slashed rel for cross-shell manifest parity with bash update.sh.
    # Closes #74: `.Replace($Target, "")` strips EVERY literal occurrence
    # of $Target from $dst, so `-Target .` collapses every dot — including
    # the dot prefix of `.codex/`, `.claude/`, and every file extension —
    # producing nonsense paths in the change report. Use a true prefix strip.
    if ($dst.StartsWith($Target)) {
        $rel = $dst.Substring($Target.Length)
    } else {
        $rel = $dst
    }
    $rel = $rel.TrimStart("\", "/").Replace("\", "/")
    $Managed.Add($rel)

    if (-not (Test-Path -LiteralPath $dst)) {
        $Changes.Add("NEW      $rel")
        $RecordActions.Add("added $rel")
        if (-not $DryRun) {
            $dir = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dir)) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
            # See install.ps1 Copy-KitFile comment: Copy-Item -Destination
            # interprets wildcards in the dst path. Use [System.IO.File]::Copy
            # for a literal-both-sides copy that survives bracketed $Target.
            [System.IO.File]::Copy($src, $dst, $true)
        }
        return
    }

    if (-not (Compare-Files $src $dst)) {
        $Changes.Add("UPDATED  $rel")
        $RecordActions.Add("updated $rel")
        if (-not $DryRun) {
            # See install.ps1 Copy-KitFile comment: Copy-Item -Destination
            # interprets wildcards in the dst path. Use [System.IO.File]::Copy
            # for a literal-both-sides copy that survives bracketed $Target.
            [System.IO.File]::Copy($src, $dst, $true)
        }
    }
}

function Update-Directory([string]$srcDir, [string]$dstDir) {
    if (-not (Test-Path -LiteralPath $srcDir)) { return }
    Get-ChildItem -LiteralPath $srcDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($srcDir.Length).TrimStart("\", "/")
        Compare-And-Update $_.FullName (Join-Path $dstDir $relative)
    }
}

# -- Update skills ---------------------------------------------------------
if ($ToolList -contains "codex")  { Update-Directory (Join-Path $KitRoot "skills") (Join-Path $Target ".agents\skills") }
if ($ToolList -contains "claude") { Update-Directory (Join-Path $KitRoot "skills") (Join-Path $Target ".claude\skills") }
if ($ToolList -contains "agy") { Update-Directory (Join-Path $KitRoot "skills") (Join-Path $Target ".agy\skills") }

# -- Update Codex tooling --------------------------------------------------
if ($ToolList -contains "codex") {
    Compare-And-Update (Join-Path $KitRoot "tooling\codex\AGENTS.md")   (Join-Path $Target "AGENTS.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\codex\config.toml") (Join-Path $Target ".codex\config.toml")
    Compare-And-Update (Join-Path $KitRoot "tooling\codex\hooks.windows.json") (Join-Path $Target ".codex\hooks.json")
    Update-Directory   (Join-Path $KitRoot "tooling\codex\hooks")       (Join-Path $Target ".codex\hooks")
    # Codex skills (5 subagents) merge into shared .agents/skills/
    Update-Directory   (Join-Path $KitRoot "tooling\codex\skills")      (Join-Path $Target ".agents\skills")

    # -- v1.14 migration: legacy .codex/agents/*.toml ---------------------
    # The Rust Codex CLI does not read this directory. Files are leftover from
    # pre-1.14 kit versions. The manifest GC below removes them only when
    # .kit-manifest proves kit ownership.
    $legacyCodexAgents = Join-Path $Target ".codex\agents"
    if (Test-Path -LiteralPath $legacyCodexAgents) {
        foreach ($legacy in @("architect", "code-reviewer", "codebase-investigator", "security-reviewer", "test-runner")) {
            $legacyFile = Join-Path $legacyCodexAgents "$legacy.toml"
            $legacyRel = ".codex/agents/$legacy.toml"
            if ((Test-Path -LiteralPath $legacyFile) -and (-not (Test-ManifestEntry $legacyRel))) {
                $Notes.Add("SKIPPED  $legacyRel (legacy; ownership unknown)")
                $RecordActions.Add("skipped $legacyRel")
            }
        }
    }
}

# -- Update Claude tooling -------------------------------------------------
if ($ToolList -contains "claude") {
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\settings.windows.json") (Join-Path $Target ".claude\settings.json")
    # .mcp.json is project-owned after install (configured by the user). Update
    # only refreshes the versioned reference; the live file is never touched.
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\.mcp.example.jsonc") (Join-Path $Target ".mcp.example.jsonc")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\agents")        (Join-Path $Target ".claude\agents")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\commands")      (Join-Path $Target ".claude\commands")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\hooks")         (Join-Path $Target ".claude\hooks")
    Update-Directory   (Join-Path $KitRoot "tooling\claude\rules")         (Join-Path $Target ".claude\rules")
}

# -- Update Antigravity tooling -------------------------------------------------
if ($ToolList -contains "agy") {
    Compare-And-Update (Join-Path $KitRoot "tooling\agy\AGY.md")      (Join-Path $Target "AGY.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\agy\.agyignore")  (Join-Path $Target ".agyignore")
    Compare-And-Update (Join-Path $KitRoot "tooling\agy\settings.windows.json")  (Join-Path $Target ".agy\settings.json")
    Update-Directory   (Join-Path $KitRoot "tooling\agy\agents")         (Join-Path $Target ".agy\agents")
    Update-Directory   (Join-Path $KitRoot "tooling\agy\commands")       (Join-Path $Target ".agy\commands")
    Update-Directory   (Join-Path $KitRoot "tooling\agy\hooks")          (Join-Path $Target ".agy\hooks")
    Update-Directory   (Join-Path $KitRoot "tooling\agy\policies")       (Join-Path $Target ".agy\policies")
}

# -- Update shared audit runtime ------------------------------------------
Update-Directory (Join-Path $KitRoot "tooling\shared\agent-audit") (Join-Path $Target ".ai-agent-kit\audit")

# -- Update shared delegation adapter -------------------------------------
Update-Directory (Join-Path $KitRoot "tooling\shared\delegate") (Join-Path $Target ".ai-agent-kit\delegate")

# NOTE: docs/ai/ is intentionally NOT updated - it contains project-specific content.

# -- Garbage-collect files the kit no longer ships -------------------------
# Manifest diff: anything in the OLD .kit-manifest that is no longer shipped
# AND whose owning tool is in this run's -Tools scope is pruned. Conservative:
#   - only paths under a known kit root are ever touched (docs/ai/, user files
#     can never match);
#   - first run (no manifest) prunes nothing - it only writes the baseline;
#   - a partial -Tools run never prunes another tool's files; preserves that
#     tool's manifest entries (KeepFromOld) for a later full run.
if ((Test-Path -LiteralPath $manifestFile) -and ($Managed.Count -gt 0)) {
    Get-Content -LiteralPath $manifestFile | ForEach-Object {
        $p = $_.Trim()
        if (-not $p) { return }
        $otool = Get-OwningTool $p
        if (-not $otool) { return }                        # not a kit artifact -> ignore
        if ($ManifestScope -notcontains $otool) {
            $KeepFromOld.Add($p)                           # other tool, out of scope
            return
        }
        $target_p = Join-Path $Target $p
        if (($Managed -notcontains $p) -and (Test-Path -LiteralPath $target_p)) {
            $Changes.Add("PRUNED   $p (no longer shipped)")
            $RecordActions.Add("pruned $p")
            if (-not $DryRun) { Remove-Item -LiteralPath $target_p -Force }
        }
    }
}

# -- Update .kit-version + .kit-manifest -----------------------------------
if (-not $DryRun) {
    # The installed tool set is independent of this run's -Tools scope:
    # `update -Tools agy` refreshes only Antigravity files but must NOT shrink
    # the recorded installed set if codex/claude were also installed before.
    # Preserve $installedTools read at the top of the script.
    $stamp = "ai-agent-kit@$KitVersion - updated $(Get-Date -Format 'yyyy-MM-dd') - tools: $installedTools"
    Write-Utf8NoBom $versionFile $stamp

    $manifestEntries = (@() + $Managed + $KeepFromOld) | Sort-Object -Unique | Where-Object { $_ }
    Write-Utf8NoBom $manifestFile (($manifestEntries -join "`n") + "`n")

    # Install audit record (#313) — only on a real run; a dry-run must not
    # mutate the target.
    Write-LifecycleAudit "update"
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

if ($Notes.Count -gt 0) {
    Write-Host "`nNotes:" -ForegroundColor Yellow
    $Notes | ForEach-Object { Write-Host "  $_" }
}
