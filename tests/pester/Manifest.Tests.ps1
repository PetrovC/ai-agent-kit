Describe "PowerShell .kit-manifest lifecycle" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "install writes a non-empty .kit-manifest and .kit-version" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $manifestPath = Join-Path $script:Target ".kit-manifest"
        Assert-AakFileExists $manifestPath
        Assert-AakFileExists (Join-Path $script:Target ".kit-version")

        $manifest = @(Get-Content -LiteralPath $manifestPath)
        if ($manifest -notcontains "CLAUDE.md") {
            throw "Manifest does not contain CLAUDE.md"
        }
        if ($manifest -notcontains ".claude/settings.json") {
            throw "Manifest does not contain .claude/settings.json"
        }
        if ($manifest -notcontains ".ai-agent-kit/audit/record-event.ps1") {
            throw "Manifest does not contain shared audit runtime"
        }
        $sorted = @($manifest | Sort-Object -Unique)
        if (($sorted -join "`n") -ne ($manifest -join "`n")) {
            throw "Manifest is not sorted or contains duplicate lines"
        }
    }

    It "install scopes the manifest to -Tools" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $manifest = Get-Content -LiteralPath (Join-Path $script:Target ".kit-manifest")
        $unexpected = @($manifest | Where-Object {
            $_ -eq "AGENTS.md" -or
            $_ -eq "AGY.md" -or
            $_ -like ".codex/*" -or
            $_ -like ".agents/*" -or
            $_ -like ".agy/*"
        })

        if ($unexpected.Count -gt 0) {
            throw "Manifest contains non-Claude entries:`n$($unexpected -join "`n")"
        }
    }

    It "partial install preserves the prior tool manifest entries" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))
        $beforeCount = @(Get-Content -LiteralPath (Join-Path $script:Target ".kit-manifest")).Count

        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "agy"))
        $manifest = @(Get-Content -LiteralPath (Join-Path $script:Target ".kit-manifest"))

        if ($manifest -notcontains "CLAUDE.md") {
            throw "Partial install dropped CLAUDE.md from manifest"
        }
        if ($manifest -notcontains "AGY.md") {
            throw "Partial install did not add AGY.md to manifest"
        }
        if ($manifest.Count -le $beforeCount) {
            throw "Expected manifest to grow after adding agy: $beforeCount -> $($manifest.Count)"
        }

        $version = Get-Content -LiteralPath (Join-Path $script:Target ".kit-version") -Raw
        if ($version -notlike "*tools: claude,agy*") {
            throw "Expected .kit-version to record tools: claude,agy. Content:`n$version"
        }
    }

    It "uninstall reads the manifest and removes only listed files" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $userDir = Join-Path $script:Target ".claude\agents"
        New-Item -ItemType Directory -Path $userDir -Force | Out-Null
        $userFile = Join-Path $userDir "my-agent.md"
        Set-Content -LiteralPath $userFile -Value "user-owned"

        Assert-AakSuccess (Invoke-AakUninstall -Arguments @("-Tools", "claude"))

        Assert-AakFileMissing (Join-Path $script:Target "CLAUDE.md")
        Assert-AakFileExists $userFile
        Assert-AakFileMissing (Join-Path $script:Target ".kit-manifest")
        Assert-AakFileMissing (Join-Path $script:Target ".kit-version")
    }

    It "partial uninstall rewrites manifest to the remaining tool entries" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude,agy"))
        Assert-AakSuccess (Invoke-AakUninstall -Arguments @("-Tools", "claude"))

        $manifestPath = Join-Path $script:Target ".kit-manifest"
        Assert-AakFileExists $manifestPath

        $manifest = @(Get-Content -LiteralPath $manifestPath)
        if ($manifest -notcontains "AGY.md") {
            throw "Partial uninstall dropped AGY.md from manifest"
        }
        if ($manifest -contains "CLAUDE.md") {
            throw "Partial uninstall left CLAUDE.md in manifest"
        }
        if ($manifest -notcontains ".ai-agent-kit/audit/record-event.ps1") {
            throw "Partial uninstall dropped shared audit runtime while agy remains installed"
        }

        $version = Get-Content -LiteralPath (Join-Path $script:Target ".kit-version") -Raw
        if ($version -notlike "*tools: agy*") {
            throw "Expected .kit-version to record tools: agy. Content:`n$version"
        }
    }

    It "full uninstall removes shared audit runtime with the last tool" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "codex"))

        Assert-AakFileExists (Join-Path $script:Target ".ai-agent-kit\audit\record-event.ps1")

        Assert-AakSuccess (Invoke-AakUninstall -Arguments @("-Tools", "codex"))

        Assert-AakFileMissing (Join-Path $script:Target ".ai-agent-kit\audit\record-event.ps1")
        Assert-AakFileMissing (Join-Path $script:Target ".kit-manifest")
        Assert-AakFileMissing (Join-Path $script:Target ".kit-version")
    }

    It "official audit opt-in writes global config outside the target project" {
        $configPath = Join-Path ([System.IO.Path]::GetTempPath()) "aak-audit-$([guid]::NewGuid().ToString('N'))\config.json"
        try {
            Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "codex", "-Audit", "official", "-AuditConfig", $configPath))

            Assert-AakFileExists $configPath
            Assert-AakFileMissing (Join-Path $script:Target ".ai-agent-kit\config.json")

            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            if ($config.audit.enabled -ne $true) {
                throw "Expected audit.enabled true in global config"
            }
            if ($config.audit.source_project_write_policy -ne "never") {
                throw "Expected source_project_write_policy never"
            }
            if ($config.audit.runtime_path.StartsWith($script:Target, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Runtime path is inside target project"
            }
        } finally {
            $configDir = Split-Path -Parent $configPath
            if (Test-Path -LiteralPath $configDir) {
                Remove-Item -LiteralPath $configDir -Recurse -Force
            }
        }
    }
}
