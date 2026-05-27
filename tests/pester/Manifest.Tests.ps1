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
            $_ -eq "GEMINI.md" -or
            $_ -like ".codex/*" -or
            $_ -like ".agents/*" -or
            $_ -like ".gemini/*"
        })

        if ($unexpected.Count -gt 0) {
            throw "Manifest contains non-Claude entries:`n$($unexpected -join "`n")"
        }
    }

    It "partial install preserves the prior tool manifest entries" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))
        $beforeCount = @(Get-Content -LiteralPath (Join-Path $script:Target ".kit-manifest")).Count

        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "gemini"))
        $manifest = @(Get-Content -LiteralPath (Join-Path $script:Target ".kit-manifest"))

        if ($manifest -notcontains "CLAUDE.md") {
            throw "Partial install dropped CLAUDE.md from manifest"
        }
        if ($manifest -notcontains "GEMINI.md") {
            throw "Partial install did not add GEMINI.md to manifest"
        }
        if ($manifest.Count -le $beforeCount) {
            throw "Expected manifest to grow after adding gemini: $beforeCount -> $($manifest.Count)"
        }

        $version = Get-Content -LiteralPath (Join-Path $script:Target ".kit-version") -Raw
        if ($version -notlike "*tools: claude,gemini*") {
            throw "Expected .kit-version to record tools: claude,gemini. Content:`n$version"
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
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude,gemini"))
        Assert-AakSuccess (Invoke-AakUninstall -Arguments @("-Tools", "claude"))

        $manifestPath = Join-Path $script:Target ".kit-manifest"
        Assert-AakFileExists $manifestPath

        $manifest = @(Get-Content -LiteralPath $manifestPath)
        if ($manifest -notcontains "GEMINI.md") {
            throw "Partial uninstall dropped GEMINI.md from manifest"
        }
        if ($manifest -contains "CLAUDE.md") {
            throw "Partial uninstall left CLAUDE.md in manifest"
        }

        $version = Get-Content -LiteralPath (Join-Path $script:Target ".kit-version") -Raw
        if ($version -notlike "*tools: gemini*") {
            throw "Expected .kit-version to record tools: gemini. Content:`n$version"
        }
    }
}
