<#
.SYNOPSIS
    Remove ai-agent-kit files from a target project.

.DESCRIPTION
    Removes only files the kit installed:
      - .kit-manifest is the source of truth: every kit-installed file is
        listed, scoped by tool (codex / claude / agy). Only manifest
        entries whose owning tool is in -Tools are removed.
      - If .kit-manifest is missing (very old installs), the script
        reconstructs the kit's installed file list from the running kit
        sources (KitRoot) and removes only those exact paths. Anything else
        inside managed dirs is left in place.

    Empty parent dirs under .agents\, .claude\, .codex\, .agy\ are pruned
    after removal so a fully-uninstalled tool leaves no empty shell behind,
    while user files inside those dirs survive untouched.

    Preserves:
      - docs/ai/ (your project content - never touched)
      - User-added files inside managed dirs (e.g. .claude\agents\my-agent.md).
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
if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }  # AAK_DEBUG: opt-in trace (#305)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

# In the repo, lifecycle scripts live in scripts/ and the kit root is one level
# up; in a release archive they sit at the archive root beside VERSION. Detect
# the layout via the VERSION sentinel.
$KitRoot = if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "VERSION") -PathType Leaf) { $PSScriptRoot } else { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }

# If no -Tools given, read from .kit-version.
if ([string]::IsNullOrWhiteSpace($Tools)) {
    $versionFile = Join-Path $Target ".kit-version"
    if (Test-Path -LiteralPath $versionFile) {
        $versionLine = (Get-Content -LiteralPath $versionFile -Raw).Trim()
        if ($versionLine -match "tools: ([^\s]+)") {
            $Tools = $Matches[1].Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($Tools)) {
        $Tools = "codex,claude,agy"
    }
}

$ToolList = @($Tools -split "," | ForEach-Object { $_.Trim().ToLower() })

$ValidTools = @("codex", "claude", "agy")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, agy"
    exit 1
}

$versionFileForScope = Join-Path $Target ".kit-version"
$installedForScope = "codex,claude,agy"
if (Test-Path -LiteralPath $versionFileForScope) {
    $versionLineForScope = (Get-Content -LiteralPath $versionFileForScope -Raw).Trim()
    if ($versionLineForScope -match "tools: ([^\s]+)") {
        $installedForScope = $Matches[1].Trim()
    }
}
$installedScopeList = @($installedForScope -split "," | ForEach-Object { $_.Trim().ToLower() })
$remainingScopeList = @($installedScopeList | Where-Object { $ToolList -notcontains $_ })
$RemoveSharedAudit = $remainingScopeList.Count -eq 0

# -- Helpers ---------------------------------------------------------------
function Step([string]$msg)      { Write-Host "`n> $msg" -ForegroundColor Cyan }
function Removed([string]$msg)   { Write-Host "  [removed] $msg" -ForegroundColor Red }
function Absent([string]$msg)    { Write-Host "  [absent] $msg" -ForegroundColor Gray }
function DryRunOut([string]$msg) { Write-Host "  [would-remove] $msg" -ForegroundColor Yellow }
function Warn([string]$msg)      { Write-Host "  ! $msg" -ForegroundColor Yellow }

# Map a kit-managed rel path to its owning tool, or "" if not a kit artifact.
# Mirrors install.sh / update.sh so the manifest and uninstall agree exactly.
# `.mcp.json` is project-owned after install and is never tracked or removed.
function Get-OwningTool([string]$rel) {
    $r = $rel -replace "\\", "/"
    if ($r -eq "AGENTS.md" -or $r -like ".codex/*" -or $r -like ".agents/skills/*") { return "codex" }
    if ($r -like ".ai-agent-kit/audit/*") { return "shared" }
    if ($r -like ".ai-agent-kit/delegate/*") { return "shared" }
    if ($r -eq "CLAUDE.md" -or $r -eq ".mcp.example.jsonc" -or $r -like ".claude/*") { return "claude" }
    if ($r -eq "AGY.md" -or $r -eq ".agyignore" -or $r -like ".agy/*") { return "agy" }
    return ""
}

function Remove-RelPath([string]$rel) {
    $path = Join-Path $Target $rel
    if (Test-Path -LiteralPath $path) {
        if ($DryRun) {
            DryRunOut $rel
        } else {
            Remove-Item -LiteralPath $path -Force
            Removed $rel
        }
    } else {
        Absent $rel
    }
}

# Reconstruct the kit's installed file list for a tool when no manifest is
# present. Only enumerates files that the running kit sources actually ship,
# mirroring install.ps1's copy operations.
function Get-ReconstructedFiles([string]$tool) {
    $out = New-Object System.Collections.Generic.List[string]
    switch ($tool) {
        "codex" {
            $out.Add("AGENTS.md")
            $out.Add(".codex/config.toml")
            $out.Add(".codex/hooks.json")
            $hooksDir = Join-Path $KitRoot "tooling/codex/hooks"
            if (Test-Path -LiteralPath $hooksDir) {
                Get-ChildItem -LiteralPath $hooksDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($hooksDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".codex/hooks/$rel")
                }
            }
            $codexSkillsDir = Join-Path $KitRoot "tooling/codex/skills"
            if (Test-Path -LiteralPath $codexSkillsDir) {
                Get-ChildItem -LiteralPath $codexSkillsDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($codexSkillsDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".agents/skills/$rel")
                }
            }
            $sharedSkillsDir = Join-Path $KitRoot "skills"
            if (Test-Path -LiteralPath $sharedSkillsDir) {
                Get-ChildItem -LiteralPath $sharedSkillsDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($sharedSkillsDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".agents/skills/$rel")
                }
            }
        }
        "claude" {
            $out.Add("CLAUDE.md")
            $out.Add(".mcp.example.jsonc")
            $out.Add(".claude/settings.json")
            foreach ($sub in @("agents","commands","hooks","rules")) {
                $d = Join-Path $KitRoot "tooling/claude/$sub"
                if (Test-Path -LiteralPath $d) {
                    Get-ChildItem -LiteralPath $d -Recurse -File | ForEach-Object {
                        $rel = $_.FullName.Substring($d.Length).TrimStart('\','/') -replace "\\", "/"
                        $out.Add(".claude/$sub/$rel")
                    }
                }
            }
            $sharedSkillsDir = Join-Path $KitRoot "skills"
            if (Test-Path -LiteralPath $sharedSkillsDir) {
                Get-ChildItem -LiteralPath $sharedSkillsDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($sharedSkillsDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".claude/skills/$rel")
                }
            }
        }
        "agy" {
            $out.Add("AGY.md")
            $out.Add(".agyignore")

            $out.Add(".agy/settings.json")
            foreach ($sub in @("agents","commands","hooks","policies")) {
                $d = Join-Path $KitRoot "tooling/agy/$sub"
                if (Test-Path -LiteralPath $d) {
                    Get-ChildItem -LiteralPath $d -Recurse -File | ForEach-Object {
                        $rel = $_.FullName.Substring($d.Length).TrimStart('\','/') -replace "\\", "/"
                        $out.Add(".agy/$sub/$rel")
                    }
                }
            }
            $sharedSkillsDir = Join-Path $KitRoot "skills"
            if (Test-Path -LiteralPath $sharedSkillsDir) {
                Get-ChildItem -LiteralPath $sharedSkillsDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($sharedSkillsDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".agy/skills/$rel")
                }
            }
        }
        "shared" {
            $auditDir = Join-Path $KitRoot "tooling/shared/agent-audit"
            if (Test-Path -LiteralPath $auditDir) {
                Get-ChildItem -LiteralPath $auditDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($auditDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".ai-agent-kit/audit/$rel")
                }
            }
            $delegateDir = Join-Path $KitRoot "tooling/shared/delegate"
            if (Test-Path -LiteralPath $delegateDir) {
                Get-ChildItem -LiteralPath $delegateDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($delegateDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".ai-agent-kit/delegate/$rel")
                }
            }
        }
    }
    return $out
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
Write-Host "  NOTE: docs/ai/ and any file not installed by the kit are preserved."
Write-Host "        Remove docs/ai/ manually if you want a clean slate."

# -- Build the removal list ------------------------------------------------
$ManifestFile = Join-Path $Target ".kit-manifest"
$ToRemove = New-Object System.Collections.Generic.List[string]

if (Test-Path -LiteralPath $ManifestFile) {
    Get-Content -LiteralPath $ManifestFile | ForEach-Object {
        $p = $_.Trim()
        if ([string]::IsNullOrEmpty($p)) { return }
        $otool = Get-OwningTool $p
        if (-not [string]::IsNullOrEmpty($otool) -and (($ToolList -contains $otool) -or ($otool -eq "shared" -and $RemoveSharedAudit))) {
            $ToRemove.Add($p)
        }
    }
} else {
    Step "No .kit-manifest found - reconstructing from kit sources"
    Warn "Without a manifest, only files this kit version still ships are removed."
    Warn "User-added files inside managed dirs are preserved by design."
    foreach ($t in $ToolList) {
        Get-ReconstructedFiles $t | ForEach-Object { $ToRemove.Add($_) }
    }
    if ($RemoveSharedAudit) {
        Get-ReconstructedFiles "shared" | ForEach-Object { $ToRemove.Add($_) }
    }
}

# Sort + dedupe (a path can be listed twice if two tools share a parent dir).
$ToRemove = @($ToRemove | Sort-Object -Unique)

# -- Remove files (kit-owned only) ----------------------------------------
foreach ($tool in $ToolList) {
    switch ($tool) {
        "codex"  { Step "Removing Codex tooling" }
        "claude" { Step "Removing Claude Code tooling" }
        "agy" { Step "Removing Antigravity CLI tooling" }
    }
    $any = $false
    foreach ($rel in $ToRemove) {
        if ((Get-OwningTool $rel) -ne $tool) { continue }
        $any = $true
        Remove-RelPath $rel
    }
    if (-not $any) {
        Write-Host "  (no files to remove for $tool)"
    }
}

if ($RemoveSharedAudit) {
    Step "Removing shared audit runtime"
    $any = $false
    foreach ($rel in $ToRemove) {
        if ((Get-OwningTool $rel) -ne "shared") { continue }
        $any = $true
        Remove-RelPath $rel
    }
    if (-not $any) {
        Write-Host "  (no files to remove for shared audit runtime)"
    }
}

# -- Prune empty kit directories ------------------------------------------
# Walk deepest first; rmdir leaves user-populated dirs alive.
if (-not $DryRun) {
    foreach ($top in @(".agents", ".claude", ".codex", ".agy", ".ai-agent-kit")) {
        $topDir = Join-Path $Target $top
        if (-not (Test-Path -LiteralPath $topDir)) { continue }
        $dirs = @(Get-ChildItem -LiteralPath $topDir -Recurse -Directory -ErrorAction SilentlyContinue) +
                @(Get-Item -LiteralPath $topDir)
        # Sort by descending depth so children are removed before parents.
        $dirs = $dirs | Sort-Object { $_.FullName.Length } -Descending
        foreach ($d in $dirs) {
            if (-not (Test-Path -LiteralPath $d.FullName)) { continue }
            if ((Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
                Remove-Item -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# -- .kit-version + .kit-manifest -----------------------------------------
# Partial uninstall must rewrite both metadata files to reflect the REMAINING
# tools — leaving the stale "tools: codex,claude,agy" line after
# `uninstall -Tools codex` makes the next default update think Codex is still
# installed and silently re-install its files. Manifest entries belonging to
# removed tools must be dropped too.
$versionFile = Join-Path $Target ".kit-version"
if (Test-Path -LiteralPath $versionFile) {
    $versionLine = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    $installedRaw = "codex,claude,agy"
    if ($versionLine -match "tools: ([^\s]+)") {
        $installedRaw = $Matches[1].Trim()
    }
    $installedVersion = "unknown"
    if ($versionLine -match "ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+)") {
        $installedVersion = $Matches[1]
    }
    $installedList = @($installedRaw -split "," | ForEach-Object { $_.Trim().ToLower() })
    $remaining = @($installedList | Where-Object { $ToolList -notcontains $_ })

    if ($remaining.Count -eq 0) {
        Step "Removing .kit-version + .kit-manifest"
        foreach ($meta in @(".kit-version", ".kit-manifest")) {
            $p = Join-Path $Target $meta
            if (Test-Path -LiteralPath $p) {
                if ($DryRun) {
                    DryRunOut $meta
                } else {
                    Remove-Item -LiteralPath $p -Force
                    Removed $meta
                }
            }
        }
    } else {
        $remainingStr = $remaining -join ","
        Step "Updating .kit-version to remaining tools: $remainingStr"
        if ($DryRun) {
            DryRunOut ".kit-version"
        } else {
            $stamp = "ai-agent-kit@$installedVersion - updated $(Get-Date -Format 'yyyy-MM-dd') - tools: $remainingStr"
            [System.IO.File]::WriteAllText(
                $versionFile,
                $stamp,
                (New-Object System.Text.UTF8Encoding($false)))
            Removed ".kit-version (rewritten)"
        }
        # Filter the manifest: keep only entries whose owning tool is still installed.
        $manifestPath = Join-Path $Target ".kit-manifest"
        if (Test-Path -LiteralPath $manifestPath) {
            if ($DryRun) {
                DryRunOut ".kit-manifest (filter)"
            } else {
                $kept = @()
                foreach ($line in (Get-Content -LiteralPath $manifestPath)) {
                    $p = $line.Trim()
                    if (-not $p) { continue }
                    $otool = Get-OwningTool $p
                    if (-not $otool) { continue }
                    if ($ToolList -contains $otool) { continue }
                    $kept += $p
                }
                $kept = @($kept | Sort-Object -Unique)
                [System.IO.File]::WriteAllText(
                    $manifestPath,
                    (($kept -join "`n") + "`n"),
                    (New-Object System.Text.UTF8Encoding($false)))
                Removed ".kit-manifest (filtered)"
            }
        }
    }
}

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|         Uninstall complete           |"
Write-Host "+--------------------------------------+"
