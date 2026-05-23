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

# Validate $Target before any I/O. Without this, a typo or a path that points
# at a file silently triggers the New-Item -ItemType Directory branches in
# Compare-And-Update and starts materializing a pseudo-install under an
# invalid root. Mirrors install.sh / update.sh which both refuse [[ ! -d ]].
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

$KitRoot    = Split-Path -Parent $PSScriptRoot
$KitVersion = "1.19.30"

function Get-OwningTool([string]$rel) {
    # Returns codex|claude|gemini or "" for non-kit paths (docs/ai/,
    # .kit-version, .kit-manifest, .mcp.json, user files) — those are never
    # pruned and never written to the manifest. `.mcp.json` is initialized by
    # install and then owned by the project; `.mcp.example.jsonc` is the
    # versioned reference.
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

function Compare-Files([string]$a, [string]$b) {
    # Returns $true if identical. Length check first, then byte-stream compare
    # with early exit on the first differing byte — the cmp -s equivalent. We
    # do not hash both whole files (Get-FileHash) because that always reads
    # them fully even when they obviously differ.
    if ((Get-Item $a).Length -ne (Get-Item $b).Length) { return $false }
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
$Changes      = [System.Collections.Generic.List[string]]::new()
$Notes        = [System.Collections.Generic.List[string]]::new()
$Managed      = [System.Collections.Generic.List[string]]::new()   # touched this run (any tool in scope)
$KeepFromOld  = [System.Collections.Generic.List[string]]::new()   # old-manifest entries for tools NOT in this run

function Test-ManifestEntry([string]$rel) {
    if (-not (Test-Path $manifestFile)) { return $false }
    foreach ($line in Get-Content $manifestFile) {
        if ($line.Trim() -eq $rel) { return $true }
    }
    return $false
}

function Compare-And-Update([string]$src, [string]$dst) {
    if (-not (Test-Path $src)) { return }

    # Forward-slashed rel for cross-shell manifest parity with bash update.sh.
    $rel = $dst.Replace($Target, "").TrimStart("\", "/").Replace("\", "/")
    $Managed.Add($rel)

    if (-not (Test-Path $dst)) {
        $Changes.Add("NEW      $rel")
        if (-not $DryRun) {
            $dir = Split-Path -Parent $dst
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item $src $dst -Force
        }
        return
    }

    if (-not (Compare-Files $src $dst)) {
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

    # -- v1.14 migration: legacy .codex/agents/*.toml ---------------------
    # The Rust Codex CLI does not read this directory. Files are leftover from
    # pre-1.14 kit versions. The manifest GC below removes them only when
    # .kit-manifest proves kit ownership.
    $legacyCodexAgents = Join-Path $Target ".codex\agents"
    if (Test-Path $legacyCodexAgents) {
        foreach ($legacy in @("architect", "code-reviewer", "codebase-investigator", "security-reviewer", "test-runner")) {
            $legacyFile = Join-Path $legacyCodexAgents "$legacy.toml"
            $legacyRel = ".codex/agents/$legacy.toml"
            if ((Test-Path $legacyFile) -and (-not (Test-ManifestEntry $legacyRel))) {
                $Notes.Add("SKIPPED  $legacyRel (legacy; ownership unknown)")
            }
        }
    }
}

# -- Update Claude tooling -------------------------------------------------
if ($ToolList -contains "claude") {
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\CLAUDE.md")     (Join-Path $Target "CLAUDE.md")
    Compare-And-Update (Join-Path $KitRoot "tooling\claude\settings.json") (Join-Path $Target ".claude\settings.json")
    # .mcp.json is project-owned after install (configured by the user). Update
    # only refreshes the versioned reference; the live file is never touched.
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
    Update-Directory   (Join-Path $KitRoot "tooling\gemini\commands")       (Join-Path $Target ".gemini\commands")
}

# NOTE: docs/ai/ is intentionally NOT updated - it contains project-specific content.

# -- Garbage-collect files the kit no longer ships -------------------------
# Manifest diff: anything in the OLD .kit-manifest that is no longer shipped
# AND whose owning tool is in this run's -Tools scope is pruned. Conservative:
#   - only paths under a known kit root are ever touched (docs/ai/, user files
#     can never match);
#   - first run (no manifest) prunes nothing - it only writes the baseline;
#   - a partial -Tools run never prunes another tool's files; preserves that
#     tool's manifest entries (KeepFromOld) for a later full run.
if ((Test-Path $manifestFile) -and ($Managed.Count -gt 0)) {
    Get-Content $manifestFile | ForEach-Object {
        $p = $_.Trim()
        if (-not $p) { return }
        $otool = Get-OwningTool $p
        if (-not $otool) { return }                        # not a kit artifact -> ignore
        if ($ToolList -notcontains $otool) {
            $KeepFromOld.Add($p)                           # other tool, out of scope
            return
        }
        if (($Managed -notcontains $p) -and (Test-Path (Join-Path $Target $p))) {
            $Changes.Add("PRUNED   $p (no longer shipped)")
            if (-not $DryRun) { Remove-Item -Path (Join-Path $Target $p) -Force }
        }
    }
}

# -- Update .kit-version + .kit-manifest -----------------------------------
if (-not $DryRun) {
    # The installed tool set is independent of this run's -Tools scope:
    # `update -Tools gemini` refreshes only Gemini files but must NOT shrink
    # the recorded installed set if codex/claude were also installed before.
    # Preserve $installedTools read at the top of the script.
    $stamp = "ai-agent-kit@$KitVersion - updated $(Get-Date -Format 'yyyy-MM-dd') - tools: $installedTools"
    Write-Utf8NoBom $versionFile $stamp

    $manifestEntries = (@() + $Managed + $KeepFromOld) | Sort-Object -Unique | Where-Object { $_ }
    Write-Utf8NoBom $manifestFile (($manifestEntries -join "`n") + "`n")
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
