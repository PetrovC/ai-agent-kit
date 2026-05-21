<#
.SYNOPSIS
    Remove ai-agent-kit files from a target project.

.DESCRIPTION
    Removes only files the kit installed:
      - .kit-manifest is the source of truth: every kit-installed file is
        listed, scoped by tool (codex / claude / gemini). Only manifest
        entries whose owning tool is in -Tools are removed.
      - If .kit-manifest is missing (very old installs), the script
        reconstructs the kit's installed file list from the running kit
        sources (KitRoot) and removes only those exact paths. Anything else
        inside managed dirs is left in place.

    Empty parent dirs under .agents\, .claude\, .codex\, .gemini\ are pruned
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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Target directory does not exist: $Target"
    exit 1
}

$KitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

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

$ToolList = @($Tools -split "," | ForEach-Object { $_.Trim().ToLower() })

$ValidTools = @("codex", "claude", "gemini")
$invalid    = @($ToolList | Where-Object { $ValidTools -notcontains $_ })
if ($invalid.Count -gt 0) {
    Write-Error "Unknown tool(s): $($invalid -join ', '). Valid options: codex, claude, gemini"
    exit 1
}

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
    if ($r -eq "CLAUDE.md" -or $r -eq ".mcp.example.jsonc" -or $r -like ".claude/*") { return "claude" }
    if ($r -eq "GEMINI.md" -or $r -eq ".geminiignore" -or $r -like ".gemini/*") { return "gemini" }
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
        "gemini" {
            $out.Add("GEMINI.md")
            $out.Add(".geminiignore")
            $out.Add(".gemini/settings.json")
            foreach ($sub in @("agents","commands")) {
                $d = Join-Path $KitRoot "tooling/gemini/$sub"
                if (Test-Path -LiteralPath $d) {
                    Get-ChildItem -LiteralPath $d -Recurse -File | ForEach-Object {
                        $rel = $_.FullName.Substring($d.Length).TrimStart('\','/') -replace "\\", "/"
                        $out.Add(".gemini/$sub/$rel")
                    }
                }
            }
            $sharedSkillsDir = Join-Path $KitRoot "skills"
            if (Test-Path -LiteralPath $sharedSkillsDir) {
                Get-ChildItem -LiteralPath $sharedSkillsDir -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($sharedSkillsDir.Length).TrimStart('\','/') -replace "\\", "/"
                    $out.Add(".gemini/skills/$rel")
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
        if (-not [string]::IsNullOrEmpty($otool) -and $ToolList -contains $otool) {
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
}

# Sort + dedupe (a path can be listed twice if two tools share a parent dir).
$ToRemove = @($ToRemove | Sort-Object -Unique)

# -- Remove files (kit-owned only) ----------------------------------------
foreach ($tool in $ToolList) {
    switch ($tool) {
        "codex"  { Step "Removing Codex tooling" }
        "claude" { Step "Removing Claude Code tooling" }
        "gemini" { Step "Removing Gemini CLI tooling" }
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

# -- Prune empty kit directories ------------------------------------------
# Walk deepest first; rmdir leaves user-populated dirs alive.
if (-not $DryRun) {
    foreach ($top in @(".agents", ".claude", ".codex", ".gemini")) {
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
$versionFile = Join-Path $Target ".kit-version"
if (Test-Path -LiteralPath $versionFile) {
    $versionLine = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    $installedRaw = "codex,claude,gemini"
    if ($versionLine -match "tools: (.+)") {
        $installedRaw = $Matches[1].Trim()
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
        Step "Keeping .kit-version"
        Write-Host "  (still installed: $($remaining -join ','))"
    }
}

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|         Uninstall complete           |"
Write-Host "+--------------------------------------+"
