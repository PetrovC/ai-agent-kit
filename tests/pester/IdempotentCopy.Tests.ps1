Describe "PowerShell idempotent file copy" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "re-running install on a clean install leaves the same files in place" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))
        $before = @(Get-AakTargetSnapshot)

        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))
        $after = @(Get-AakTargetSnapshot)

        if (($before -join "`n") -ne ($after -join "`n")) {
            throw "Install is not idempotent (file content changed)"
        }
    }

    It "update.ps1 on an unchanged install reports up to date" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $result = Invoke-AakUpdate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "Everything is up to date"
    }

    It "update.ps1 restores a locally-mutated managed file" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $claudeFile = Join-Path $script:Target "CLAUDE.md"
        $canonical = Get-Content -LiteralPath (Join-Path $script:KitRoot "tooling\claude\CLAUDE.md") -Raw
        Add-Content -LiteralPath $claudeFile -Value "LOCAL DRIFT"

        $result = Invoke-AakUpdate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "UPDATED  CLAUDE.md"

        $actual = Get-Content -LiteralPath $claudeFile -Raw
        if ($actual -ne $canonical) {
            throw "CLAUDE.md was not restored to canonical content"
        }
    }

    It "update.ps1 prunes a manifest-listed file the kit no longer ships" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $stale = Join-Path $script:Target ".claude\commands\stale-command.md"
        New-Item -ItemType Directory -Path (Split-Path -Parent $stale) -Force | Out-Null
        Set-Content -LiteralPath $stale -Value "stale"
        Add-Content -LiteralPath (Join-Path $script:Target ".kit-manifest") -Value ".claude/commands/stale-command.md"

        $result = Invoke-AakUpdate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "PRUNED   .claude/commands/stale-command.md"
        Assert-AakFileMissing $stale
    }
}
