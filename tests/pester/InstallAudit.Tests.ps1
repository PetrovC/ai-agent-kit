Describe "Install/update audit record (#313)" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "install writes an audit record listing managed actions" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))

        $record = Join-Path $script:Target ".ai-agent-kit\install-audit.ndjson"
        Assert-AakFileExists $record
        $lines = @(Get-Content -LiteralPath $record | Where-Object { $_.Trim() })
        if ($lines.Count -ne 1) { throw "expected 1 run, got $($lines.Count)" }
        $r = $lines[0] | ConvertFrom-Json
        if ($r.action -ne "install") { throw "action $($r.action)" }
        if (-not $r.kit_version) { throw "missing kit_version" }
        if ($r.occurred_at -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') { throw "occurred_at $($r.occurred_at)" }
        if ($r.summary.added -le 0) { throw "expected added > 0, got $($r.summary.added)" }
        if ($r.summary.updated -ne 0) { throw "expected updated 0, got $($r.summary.updated)" }
        if (@($r.changes).Count -lt 1) { throw "expected change entries" }
    }

    It "update appends an update record and a dry-run writes none" {
        Assert-AakSuccess (Invoke-AakInstall -Arguments @("-Tools", "claude"))
        # Force one managed file to differ so update records an UPDATED action.
        $claudeMd = Join-Path $script:Target "CLAUDE.md"
        Add-Content -LiteralPath $claudeMd -Value "`n# local drift`n"
        Assert-AakSuccess (Invoke-AakUpdate -Arguments @("-Tools", "claude"))
        Assert-AakSuccess (Invoke-AakUpdate -Arguments @("-Tools", "claude", "-DryRun"))

        $record = Join-Path $script:Target ".ai-agent-kit\install-audit.ndjson"
        $runs = @(Get-Content -LiteralPath $record | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        $actions = @($runs | ForEach-Object { $_.action })
        if (($actions -join ",") -ne "install,update") { throw "dry-run must not append; got $($actions -join ',')" }
        if ($runs[1].summary.updated -lt 1) { throw "expected updated >= 1, got $($runs[1].summary.updated)" }
    }
}
