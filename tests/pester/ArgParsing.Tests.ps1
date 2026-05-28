Describe "PowerShell lifecycle argument parsing" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "install.ps1 fails without -Target" {
        $result = Invoke-AakPowerShellScript -Script (Join-Path $script:KitRoot "scripts\install.ps1")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Target"
    }

    It "install.ps1 rejects -Target pointing at a missing directory" {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "aak-missing-$([guid]::NewGuid().ToString('N'))"

        $result = Invoke-AakPowerShellScript `
            -Script (Join-Path $script:KitRoot "scripts\install.ps1") `
            -Arguments @("-Target", $missing)

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Target directory does not exist"
    }

    It "install.ps1 rejects -Target consumed by another parameter" {
        $result = Invoke-AakPowerShellScript `
            -Script (Join-Path $script:KitRoot "scripts\install.ps1") `
            -Arguments @("-Target", "-Tools", "claude")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Target"
    }

    It "install.ps1 rejects an unknown tool" {
        $result = Invoke-AakInstall -Arguments @("-Tools", "bogus")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Unknown tool"
    }

    It "install.ps1 rejects an empty -Tools list" {
        $result = Invoke-AakInstall -Arguments @("-Tools", ", ,")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Unknown tool"
    }

    It "install.ps1 rejects an unknown argument" {
        $result = Invoke-AakPowerShellScript `
            -Script (Join-Path $script:KitRoot "scripts\install.ps1") `
            -Arguments @("-Target", $script:Target, "-Frobnicate")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Frobnicate"
    }

    It "install.ps1 normalizes -Tools to lowercase and canonical order in .kit-version" {
        $result = Invoke-AakInstall -Arguments @("-Tools", "agy, Claude")
        Assert-AakSuccess $result

        $version = Get-Content -LiteralPath (Join-Path $script:Target ".kit-version") -Raw
        if ($version -notlike "*tools: claude,agy*") {
            throw "Expected .kit-version to record tools: claude,agy. Content:`n$version"
        }
    }

    It "update.ps1 -DryRun reports changes without modifying the target" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $claudeFile = Join-Path $script:Target "CLAUDE.md"
        Add-Content -LiteralPath $claudeFile -Value "LOCAL DRIFT"

        $result = Invoke-AakUpdate -Arguments @("-DryRun")

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "UPDATED  CLAUDE.md"
        Assert-AakOutputContains $result "Run without -DryRun to apply"

        $content = Get-Content -LiteralPath $claudeFile -Raw
        if ($content -notlike "*LOCAL DRIFT*") {
            throw "Dry-run update unexpectedly overwrote CLAUDE.md"
        }
    }

    It "uninstall.ps1 -DryRun reports removals without deleting" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))
        $claudeFile = Join-Path $script:Target "CLAUDE.md"
        Assert-AakFileExists $claudeFile

        $result = Invoke-AakUninstall -Arguments @("-DryRun")

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "would-remove"
        Assert-AakFileExists $claudeFile
    }

    It "new-skill.ps1 rejects an invalid skill name" {
        $result = Invoke-AakPowerShellScript `
            -Script (Join-Path $script:KitRoot "scripts\new-skill.ps1") `
            -Arguments @("-Name", "Bad_Name")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "Skill name must be lowercase"
    }
}
