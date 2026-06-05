<#
.SYNOPSIS
    Check that docs/ai/* templates have been filled in a target project.

.DESCRIPTION
    Detects:
      - Required files missing (every project-template/*.md must ship to docs/ai/).
      - "STOP" notices still present in templates.
      - HTML-comment placeholders still present (<!-- ... -->).
      - Non-comment placeholders still present (empty table rows, "TBD" cells,
        pure-dots list items, "<key>: ..." placeholder values).
      - Codex router files stay under the documented context budget and link
        to the long-run context/model/subagent guidance.
      - A compact context audit lists the largest Codex-facing files.
      - In this source repository only, tracked Claude/Codex/Antigravity dogfood
        files drifted (content or git mode) from their canonical sources
        under tooling/ or skills/.

    Exit codes:
      0 - everything OK
      1 - issues found (or usage error)

.PARAMETER Target
    Path to the project root to validate.

.EXAMPLE
    .\validate.ps1 -Target "C:\Projects\my-project"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [switch]$Strict,

    [Nullable[int]]$RouterMaxLines = $null
)
if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }  # AAK_DEBUG: opt-in trace (#305)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DocsAi = Join-Path $Target "docs\ai"
# Closes #89: every Test-Path / Get-ChildItem / Select-String on a path
# derived from $Target uses -LiteralPath so a project at e.g.
# `C:\work\[acme]\app` is treated as a literal filesystem path, not a
# wildcard pattern that would silently miss the docs directory.
if (-not (Test-Path -LiteralPath $DocsAi)) {
    Write-Error "$DocsAi does not exist. Run install.ps1 first."
    exit 1
}

$Required = @("PROJECT.md", "ARCHITECTURE.md", "COMMANDS.md", "DECISIONS.md", "GLOSSARY.md", "ROADMAP.md", "TESTING.md")
$ResolvedRouterMaxLines = 320
if ($env:AAK_ROUTER_MAX_LINES) {
    $envValue = 0
    if (-not [int]::TryParse($env:AAK_ROUTER_MAX_LINES, [ref]$envValue) -or $envValue -le 0) {
        Write-Error "AAK_ROUTER_MAX_LINES must be a positive integer. Got '$($env:AAK_ROUTER_MAX_LINES)'."
        exit 1
    }
    $ResolvedRouterMaxLines = $envValue
}
if ($PSBoundParameters.ContainsKey('RouterMaxLines')) {
    if ($null -eq $RouterMaxLines -or [int]$RouterMaxLines -le 0) {
        Write-Error "RouterMaxLines must be a positive integer."
        exit 1
    }
    $ResolvedRouterMaxLines = [int]$RouterMaxLines
}
$CodexRouterMaxBytes = 16384
$CodexRequiredLinks = @(
    "docs/ai/CONTEXT_GOVERNANCE.md",
    "docs/ai/MODEL_ROUTING.md",
    "docs/ai/SUBAGENT_GOVERNANCE.md"
)
$AgentContextTopN = 5
$Issues = 0

function Warn([string]$msg) {
    Write-Host "  ! $msg" -ForegroundColor Yellow
    $script:Issues++
}

function Ok([string]$msg) {
    Write-Host "  [ok] $msg" -ForegroundColor Green
}

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|        ai-agent-kit validator        |"
Write-Host "+--------------------------------------+"
Write-Host "  Target: $Target"
Write-Host ""

# Required files
Write-Host "> Required files in docs/ai/"
foreach ($f in $Required) {
    if (Test-Path -LiteralPath (Join-Path $DocsAi $f)) {
        Ok "$f present"
    } else {
        Warn "$f MISSING"
    }
}

# STOP notices
Write-Host ""
Write-Host "> Templates still showing STOP notice (must be filled)"
$stopFound = $false
Get-ChildItem -LiteralPath $DocsAi -Filter "*.md" -File | ForEach-Object {
    if (Select-String -LiteralPath $_.FullName -Pattern "^> .*STOP|⚠️.*STOP" -Quiet -CaseSensitive) {
        Warn "$($_.Name) still contains a STOP notice"
        $stopFound = $true
    }
}
if (-not $stopFound) { Ok "no STOP notices remaining" }

# HTML comment placeholders
Write-Host ""
Write-Host "> Templates still containing HTML-comment placeholders"
$placeholdersFound = $false
Get-ChildItem -LiteralPath $DocsAi -Filter "*.md" -File | ForEach-Object {
    $hits = @(Select-String -LiteralPath $_.FullName -Pattern "<!--\s*[A-Za-z]")
    if ($hits.Count -gt 0) {
        Warn "$($_.Name): $($hits.Count) placeholder comment(s) remaining"
        $placeholdersFound = $true
    }
}
if (-not $placeholdersFound) { Ok "no placeholder comments remaining" }

# Non-comment placeholders (template patterns the previous checks miss).
# Skips fenced code blocks and HTML comments so legitimate prose / examples
# don't trip the detector. Patterns flagged:
#   - empty table rows:        | | |
#   - "TBD" cells:             | TBD |
#   - pure-dots list items:    - ...   * ...   1. ...   - [ ] ...   - [x] ...
#   - placeholder key/values:  ### Flow 1: ...   **Name**: ...   Goal: ...
Write-Host ""
Write-Host "> Templates still containing non-comment placeholders"
$nonCommentFound = $false
Get-ChildItem -LiteralPath $DocsAi -Filter "*.md" -File | ForEach-Object {
    $file = $_
    $inCode = $false
    $inComment = $false
    $hits = 0
    foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
        if ($line -match '^\s*```') { $inCode = -not $inCode; continue }
        if ($inCode) { continue }
        if (-not $inComment -and $line -match '<!--' -and $line -notmatch '-->') {
            $inComment = $true; continue
        }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -match '<!--.*-->') { continue }

        if ($line -match '^\s*\|(\s*\|)+\s*$' `
            -or $line -match '\|\s*TBD\s*\|' `
            -or $line -match '^\s*(-|\*|\d+\.)\s+(\[[\sxX]\]\s+)?\.\.\.\s*$' `
            -or $line -match ':\s+\.\.\.\s*$') {
            $hits++
        }
    }
    if ($hits -gt 0) {
        Warn "$($file.Name): $hits non-comment placeholder(s) remaining"
        $nonCommentFound = $true
    }
}
if (-not $nonCommentFound) { Ok "no non-comment placeholders remaining" }

function Join-TargetRelative([string]$rel) {
    $path = $Target
    foreach ($part in ($rel -split "/")) {
        if ($part) {
            $path = Join-Path $path $part
        }
    }
    return $path
}

function Convert-ToTargetRelative([string]$path) {
    $root = (Resolve-Path -LiteralPath $Target).Path.TrimEnd([char]'\', [char]'/')
    $full = (Resolve-Path -LiteralPath $path).Path
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart([char]'\', [char]'/') -replace "\\", "/"
    }
    return $path -replace "\\", "/"
}

function Add-AgentContextFile([hashtable]$files, [string]$rel) {
    $path = Join-TargetRelative $rel
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $item = Get-Item -LiteralPath $path
        $files[$item.FullName] = $item
    }
}

function Add-AgentContextFiles([hashtable]$files, [string]$rel, [string]$filter) {
    $path = Join-TargetRelative $rel
    if (Test-Path -LiteralPath $path -PathType Container) {
        Get-ChildItem -LiteralPath $path -Filter $filter -File -Recurse | ForEach-Object {
            $files[$_.FullName] = $_
        }
    }
}

Write-Host ""
Write-Host "> Router line budget"
$routerFailed = $false
$routerFiles = @(@(
    "AGENTS.md",
    "CLAUDE.md",
    "AGY.md",
    "tooling/codex/AGENTS.md",
    "tooling/claude/CLAUDE.md",
    "tooling/agy/AGY.md"
) | Where-Object {
    Test-Path -LiteralPath (Join-TargetRelative $_) -PathType Leaf
})

if ($routerFiles.Count -eq 0) {
    Ok "no router files found"
} else {
    foreach ($rel in $routerFiles) {
        $path = Join-TargetRelative $rel
        $content = Get-Content -LiteralPath $path -Raw
        $lineCount = ([regex]::Matches($content, "`n")).Count
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            $lineCount++
        }

        if ($lineCount -gt $ResolvedRouterMaxLines) {
            Warn "$rel has $lineCount lines; budget is $ResolvedRouterMaxLines"
            $routerFailed = $true
        }

        if ($rel -in @("AGENTS.md", "tooling/codex/AGENTS.md")) {
            $byteCount = (Get-Item -LiteralPath $path).Length
            if ($byteCount -gt $CodexRouterMaxBytes) {
                Warn "$rel is $byteCount bytes; budget is $CodexRouterMaxBytes"
                $routerFailed = $true
            }
            foreach ($link in $CodexRequiredLinks) {
                if (-not $content.Contains($link)) {
                    Warn "$rel missing link to $link"
                    $routerFailed = $true
                }
            }
        }
    }

    if (-not $routerFailed) {
        Ok "router files stay within $ResolvedRouterMaxLines lines"
        if (($routerFiles -contains "AGENTS.md") -or ($routerFiles -contains "tooling/codex/AGENTS.md")) {
            Ok "Codex AGENTS routers stay within $CodexRouterMaxBytes bytes and link context/model/subagent guidance"
        }
    }
}

# Closes #315: always-on routers and kit-authored docs/ai guidance must stay at
# or under 200 lines so directives load fast and deep detail moves to on-demand
# files. Exceptions are large on-demand reference specs (splitting tracked in
# #325); skills carry their own budget under #158. Mirrors validate.sh.
Write-Host ""
Write-Host "> Model-read doc budget (<= 200 lines)"
$DocBudgetMax = 200
# The audit reference specs were split into <=200-line cores plus on-demand
# companions under docs/ai/references/ (#325); references/ is not swept, so the
# deep detail can be long there.
$DocBudgetExceptions = @()
$docBudgetFiles = @()
foreach ($r in @("AGENTS.md", "CLAUDE.md", "AGY.md")) {
    if (Test-Path -LiteralPath (Join-Path $Target $r)) { $docBudgetFiles += $r }
}
# Kit-authored docs/ai guidance exists only in the source repo; project installs
# receive only project-template docs/ai/* (project-owned, unbounded).
$docsAiDir = Join-Path $Target "docs/ai"
if ((Test-Path -LiteralPath (Join-Path $Target ".kit-manifest")) -and
    (Test-Path -LiteralPath (Join-Path $Target "tooling")) -and
    (Test-Path -LiteralPath $docsAiDir)) {
    $templateDocs = @("PROJECT.md", "ARCHITECTURE.md", "COMMANDS.md", "DECISIONS.md", "GLOSSARY.md", "ROADMAP.md", "TESTING.md")
    Get-ChildItem -LiteralPath $docsAiDir -Filter *.md -File | ForEach-Object {
        if ($templateDocs -notcontains $_.Name) { $docBudgetFiles += "docs/ai/$($_.Name)" }
    }
}
$docBudgetFailed = $false
foreach ($rel in $docBudgetFiles) {
    if ($DocBudgetExceptions -contains $rel) { continue }
    $lineCount = @(Get-Content -LiteralPath (Join-Path $Target $rel)).Count
    if ($lineCount -gt $DocBudgetMax) {
        Warn "$rel has $lineCount lines; model-read budget is $DocBudgetMax (trim, or add to the documented exception list)"
        $docBudgetFailed = $true
    }
}
if (-not $docBudgetFailed) {
    Ok "model-read docs within $DocBudgetMax lines ($($DocBudgetExceptions.Count) documented exceptions)"
}

Write-Host ""
Write-Host "> Strict mode: project-owned update guard"
if (-not $Strict) {
    Ok "strict checks disabled (use -Strict)"
} else {
    $strictManifest = Join-Path $Target ".kit-manifest"
    $strictHasManifest = Test-Path -LiteralPath $strictManifest -PathType Leaf
    $strictHasToolSource = (Test-Path -LiteralPath (Join-Path $Target "tooling\codex") -PathType Container) `
        -or (Test-Path -LiteralPath (Join-Path $Target "tooling\claude") -PathType Container) `
        -or (Test-Path -LiteralPath (Join-Path $Target "tooling\agy") -PathType Container)

    if (-not ($strictHasManifest -and $strictHasToolSource)) {
        Ok "not a dogfood source tree; skipping strict update guard"
    } else {
        $updateScript = Join-Path $Target "scripts\update.ps1"
        if (-not (Test-Path -LiteralPath $updateScript -PathType Leaf)) {
            Ok "no scripts/update.ps1 in target; skipping strict update guard"
        } else {
            $powershellCmd = Get-Command powershell.exe -ErrorAction SilentlyContinue
            if (-not $powershellCmd) {
                Warn "strict update guard: powershell.exe not found"
            } else {
                $previousErrorActionPreference = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                try {
                    $updateOutput = @(& $powershellCmd.Source -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $updateScript -Target $Target -DryRun 2>&1)
                    $updateExitCode = $LASTEXITCODE
                } finally {
                    $ErrorActionPreference = $previousErrorActionPreference
                }

                if ($updateExitCode -ne 0) {
                    Warn "strict update guard: scripts/update.ps1 -DryRun failed"
                } else {
                    $strictHits = @(
                        $updateOutput |
                            ForEach-Object { $_.ToString() } |
                            Where-Object {
                                $_ -match '^\s*(NEW|UPDATED|PRUNED|REMOVED)\s+(docs[\\/]+ai[\\/]|\.mcp\.json(\s|$))'
                            }
                    )
                    if ($strictHits.Count -gt 0) {
                        foreach ($line in $strictHits) {
                            Warn "strict update guard: would modify project-owned path -> $line"
                        }
                    } else {
                        Ok "update dry-run preserves docs/ai/ and .mcp.json"
                    }
                }
            }
        }
    }
}

Write-Host ""
Write-Host "> Codex-facing context audit (largest files)"
$agentContextFiles = @{}
Add-AgentContextFile $agentContextFiles "AGENTS.md"
Add-AgentContextFiles $agentContextFiles "docs/ai" "*.md"
Add-AgentContextFiles $agentContextFiles "skills" "SKILL.md"
Add-AgentContextFiles $agentContextFiles ".agents/skills" "SKILL.md"
Add-AgentContextFile $agentContextFiles ".codex/config.toml"
Add-AgentContextFile $agentContextFiles ".codex/hooks.json"
Add-AgentContextFile $agentContextFiles "tooling/codex/AGENTS.md"
Add-AgentContextFiles $agentContextFiles "tooling/codex" "*.toml"
Add-AgentContextFiles $agentContextFiles "tooling/codex" "*.json"

if ($agentContextFiles.Count -eq 0) {
    Ok "no Codex-facing files found"
} else {
    $agentContextFiles.Values |
        Sort-Object Length -Descending |
        Select-Object -First $AgentContextTopN |
        ForEach-Object {
            $size = $_.Length / 1KB
            Write-Host ("  {0,6:n1} KiB  {1}" -f $size, (Convert-ToTargetRelative $_.FullName))
        }
}

# Closes #193: every shared skill under skills/<name>/SKILL.md must declare
# an `allowed-tools:` block in its YAML frontmatter, so Claude can scope tool
# access predictably. The pr-docs lint already enforces the SHAPE of each
# entry (`Bash(<cmd>:*)`); this check guarantees the field is present at all.
# Skipped silently in target projects that do not ship a top-level skills/
# directory (the kit installs skills under .claude/.agents/.agy instead).
Write-Host ""
Write-Host "> Skill frontmatter: allowed-tools required"
$skillsDir = Join-Path $Target "skills"
if (Test-Path -LiteralPath $skillsDir -PathType Container) {
    $skillFiles = @(Get-ChildItem -LiteralPath $skillsDir -Directory |
        ForEach-Object { Join-Path $_.FullName "SKILL.md" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($skillFiles.Count -eq 0) {
        Ok "no shared skills/ directory to check"
    } else {
        $skillAtMissing = $false
        foreach ($f in $skillFiles) {
            $found = $false
            $inFm = $false
            $closed = $false
            foreach ($line in (Get-Content -LiteralPath $f)) {
                if ($line -match '^---\s*$') {
                    if (-not $inFm) { $inFm = $true; continue }
                    $closed = $true; break
                }
                if ($inFm -and $line -match '^allowed-tools:\s*$') { $found = $true }
            }
            if (-not $found) {
                $rel = Convert-ToTargetRelative $f
                Warn "$rel missing allowed-tools in frontmatter"
                $skillAtMissing = $true
            }
        }
        if (-not $skillAtMissing) { Ok "all shared skills declare allowed-tools" }
    }
} else {
    Ok "no shared skills/ directory to check"
}

Write-Host ""
Write-Host "> Skill frontmatter: version required"
if (Test-Path -LiteralPath $skillsDir -PathType Container) {
    $skillFiles = @(Get-ChildItem -LiteralPath $skillsDir -Directory |
        ForEach-Object { Join-Path $_.FullName "SKILL.md" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($skillFiles.Count -eq 0) {
        Ok "no shared skills/ directory to check"
    } else {
        $skillVersionMissing = $false
        foreach ($f in $skillFiles) {
            $found = $false
            $inFm = $false
            $closed = $false
            foreach ($line in (Get-Content -LiteralPath $f)) {
                if ($line -match '^---\s*$') {
                    if (-not $inFm) { $inFm = $true; continue }
                    $closed = $true; break
                }
                if ($inFm -and $line -match '^version:\s*') { $found = $true }
            }
            if (-not $found) {
                $rel = Convert-ToTargetRelative $f
                Warn "$rel missing version in frontmatter"
                $skillVersionMissing = $true
            }
        }
        if (-not $skillVersionMissing) { Ok "all shared skills declare version" }
    }
} else {
    Ok "no shared skills/ directory to check"
}

function Get-DogfoodSourceCandidates([string]$rel) {
    switch -Regex ($rel) {
        "^AGENTS\.md$" { return @("tooling/codex/AGENTS.md") }
        "^CLAUDE\.md$" { return @("tooling/claude/CLAUDE.md") }
        "^\.mcp\.example\.jsonc$" { return @("tooling/claude/.mcp.example.jsonc") }

        "^\.codex/config\.toml$" { return @("tooling/codex/config.toml") }
        "^\.codex/hooks\.json$" { return @("tooling/codex/hooks.json", "tooling/codex/hooks.windows.json") }
        "^\.codex/hooks/(.+)$" { return @("tooling/codex/hooks/$($Matches[1])") }
        "^\.agents/skills/(.+)$" {
            $tail = $Matches[1]
            $candidates = @()
            $codexSkill = "tooling/codex/skills/$tail"
            if (Test-Path -LiteralPath (Join-TargetRelative $codexSkill) -PathType Leaf) {
                $candidates += $codexSkill
            }
            $candidates += "skills/$tail"
            return $candidates
        }
        "^\.ai-agent-kit/audit/(.+)$" { return @("tooling/shared/agent-audit/$($Matches[1])") }
        "^\.ai-agent-kit/delegate/(.+)$" { return @("tooling/shared/delegate/$($Matches[1])") }

        "^\.claude/settings\.json$" { return @("tooling/claude/settings.json", "tooling/claude/settings.windows.json") }
        "^\.claude/agents/(.+)$" { return @("tooling/claude/agents/$($Matches[1])") }
        "^\.claude/commands/(.+)$" { return @("tooling/claude/commands/$($Matches[1])") }
        "^\.claude/hooks/(.+)$" { return @("tooling/claude/hooks/$($Matches[1])") }
        "^\.claude/rules/(.+)$" { return @("tooling/claude/rules/$($Matches[1])") }
        "^\.claude/skills/(.+)$" { return @("skills/$($Matches[1])") }

        "^AGY\.md$" { return @("tooling/agy/AGY.md") }
        "^\.agyignore$" { return @("tooling/agy/.agyignore") }
        "^\.agy/settings\.json$" { return @("tooling/agy/settings.json", "tooling/agy/settings.windows.json") }
        "^\.agy/agents/(.+)$" { return @("tooling/agy/agents/$($Matches[1])") }
        "^\.agy/commands/(.+)$" { return @("tooling/agy/commands/$($Matches[1])") }
        "^\.agy/hooks/(.+)$" { return @("tooling/agy/hooks/$($Matches[1])") }
        "^\.agy/policies/(.+)$" { return @("tooling/agy/policies/$($Matches[1])") }
        "^\.agy/skills/(.+)$" { return @("skills/$($Matches[1])") }
    }
    return @()
}

function Test-SameFile([string]$left, [string]$right) {
    if (-not (Test-Path -LiteralPath $left -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $right -PathType Leaf)) { return $false }
    $leftHash = (Get-FileHash -LiteralPath $left -Algorithm SHA256).Hash
    $rightHash = (Get-FileHash -LiteralPath $right -Algorithm SHA256).Hash
    return $leftHash -eq $rightHash
}

$manifestPath = Join-Path $Target ".kit-manifest"
$codexSource = Join-Path $Target "tooling\codex"
$claudeSource = Join-Path $Target "tooling\claude"
$agySource = Join-Path $Target "tooling\agy"
$hasManifest = Test-Path -LiteralPath $manifestPath -PathType Leaf
$hasAnyToolSource = (Test-Path -LiteralPath $codexSource -PathType Container) `
    -or (Test-Path -LiteralPath $claudeSource -PathType Container) `
    -or (Test-Path -LiteralPath $agySource -PathType Container)
if ($hasManifest -and $hasAnyToolSource) {
    Write-Host ""
    Write-Host "> Dogfood install drift (repo only)"
    $dogfoodChecked = 0
    $dogfoodFound = $false

    foreach ($relRaw in (Get-Content -LiteralPath $manifestPath)) {
        $rel = $relRaw.Trim().TrimStart([char]0xFEFF)
        if (-not $rel) { continue }
        if ($rel -in @(".kit-version", ".kit-manifest", ".mcp.json")) { continue }

        $dst = Join-TargetRelative $rel
        if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) {
            Warn "$rel missing from dogfood install"
            $dogfoodFound = $true
            continue
        }

        $candidates = @(Get-DogfoodSourceCandidates $rel)
        if ($candidates.Count -eq 0) { continue }

        $sourceFound = $false
        $sourceMatch = $false
        $matchedSrcRel = $null
        foreach ($candidate in $candidates) {
            $src = Join-TargetRelative $candidate
            if (Test-Path -LiteralPath $src -PathType Leaf) {
                $sourceFound = $true
                if (Test-SameFile $src $dst) {
                    $sourceMatch = $true
                    $matchedSrcRel = $candidate
                    break
                }
            }
        }

        if (-not $sourceFound) {
            Warn "$rel has no source candidate under tooling/ or skills/"
            $dogfoodFound = $true
        } elseif (-not $sourceMatch) {
            Warn "$rel differs from its source under tooling/ or skills/"
            $dogfoodFound = $true
        } else {
            # Content matches; also enforce git-tracked mode parity.
            # A .sh source at 100755 must not become 100644 in dogfood —
            # that breaks hook execution on POSIX.
            $srcMode = $null
            $dstMode = $null
            try {
                $srcLine = & git -C $Target ls-files -s -- $matchedSrcRel 2>$null | Select-Object -First 1
                $dstLine = & git -C $Target ls-files -s -- $rel 2>$null | Select-Object -First 1
                if ($srcLine) { $srcMode = ($srcLine -split '\s+')[0] }
                if ($dstLine) { $dstMode = ($dstLine -split '\s+')[0] }
            } catch {
                $srcMode = $null; $dstMode = $null
            }
            if ($srcMode -and $dstMode -and ($srcMode -ne $dstMode)) {
                Warn "$rel git mode $dstMode differs from source $matchedSrcRel mode $srcMode"
                $dogfoodFound = $true
            } else {
                $dogfoodChecked++
            }
        }
    }

    if (-not $dogfoodFound) {
        Ok "$dogfoodChecked dogfood file(s) match source"
    }
}

Write-Host ""
Write-Host "> Release metadata"
$changelogPath = Join-Path $Target "CHANGELOG.md"
if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) {
    Ok "no CHANGELOG.md; skipping release metadata checks"
} else {
    $cl = Get-Content -LiteralPath $changelogPath -Raw

    # Exactly one [Unreleased] section
    $clUnreleased = ([regex]::Matches($cl, "(?m)^## \[Unreleased\]")).Count
    if ($clUnreleased -eq 0) {
        Warn "CHANGELOG.md: no [Unreleased] section"
    } elseif ($clUnreleased -gt 1) {
        Warn "CHANGELOG.md: $clUnreleased [Unreleased] sections (expected exactly 1)"
    } else {
        Ok "CHANGELOG.md: exactly one [Unreleased] section"
    }

    # No duplicate version section headings (full version including pre-release suffix)
    $versionMatches = [regex]::Matches($cl, "(?m)^## \[(\d+\.\d+\.\d+(-[A-Za-z0-9.]+)?)\]")
    $seenVersions = @{}
    $clHasDupe = $false
    foreach ($m in $versionMatches) {
        $v = $m.Groups[1].Value
        if ($seenVersions.ContainsKey($v)) {
            Warn "CHANGELOG.md: duplicate version section [$v]"
            $clHasDupe = $true
        } else {
            $seenVersions[$v] = $true
        }
    }
    if (-not $clHasDupe) { Ok "CHANGELOG.md: no duplicate version sections" }

    # Version headings must use valid format:
    #   ## [X.Y.Z] or ## [X.Y.Z-pre] or ## [X.Y.Z] - YYYY-MM-DD or ## [X.Y.Z-pre] - YYYY-MM-DD
    $allHeadings = [regex]::Matches($cl, "(?m)^## \[.+")
    $clBadHeadings = $false
    foreach ($m in $allHeadings) {
        $h = $m.Value.TrimEnd()
        if ($h -match "^## \[Unreleased\]") { continue }
        if ($h -notmatch "^## \[\d+\.\d+\.\d+(-[A-Za-z0-9.]+)?\]( - \d{4}-\d{2}-\d{2})?$") {
            Warn "CHANGELOG.md: invalid heading format: $h"
            $clBadHeadings = $true
        }
    }
    if (-not $clBadHeadings) { Ok "CHANGELOG.md: all version headings use valid format" }
}

Write-Host ""
if ($Issues -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$Issues issue(s) found. Fill the templates before letting agents read docs/ai/." -ForegroundColor Yellow
    exit 1
}
