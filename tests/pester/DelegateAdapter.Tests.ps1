Describe "Cross-tool delegation adapter" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        $script:AuditRoot = Join-Path ([System.IO.Path]::GetTempPath()) "aak-delegate-$([guid]::NewGuid().ToString('N'))"
        $script:RuntimePath = Join-Path $script:AuditRoot "runtime"
        $script:CentralPath = Join-Path $script:AuditRoot "central"
        $script:Bin = Join-Path $script:AuditRoot "bin"
        $script:ConfigPath = Join-Path $script:AuditRoot "config.json"
        $script:StubRecord = Join-Path $script:AuditRoot "argv.txt"
        $script:BriefPath = Join-Path $script:AuditRoot "brief.txt"
        New-Item -ItemType Directory -Path $script:RuntimePath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:CentralPath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:Bin -Force | Out-Null
        & git -C $script:CentralPath init | Out-Null
        & git -C $script:CentralPath checkout -b agent-audit-data | Out-Null
        Write-DelegateConfig $script:ConfigPath
        Write-CodexStub
        [System.IO.File]::WriteAllText($script:BriefPath, "Please review the auth module for injection risks.", (New-Object System.Text.UTF8Encoding($false)))
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) { Remove-AakPesterTarget }
        if ($script:AuditRoot -and (Test-Path -LiteralPath $script:AuditRoot)) {
            Remove-Item -LiteralPath $script:AuditRoot -Recurse -Force
        }
    }

    BeforeAll {
        function Write-DelegateConfig {
            param([string]$Path)
            $audit = [ordered]@{
                enabled = $true
                mode = "official-central-repo"
                branch = "agent-audit-data"
                runtime_path = $script:RuntimePath
                central_repo_path = $script:CentralPath
                source_project_write_policy = "never"
                push = [ordered]@{ mode = "disabled"; commit = $false }
            }
            $config = [ordered]@{ schema_version = "0.1.0"; audit = $audit }
            [System.IO.File]::WriteAllText($Path, ($config | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        }

        # A .cmd stub is resolvable by the Windows process launcher (PATHEXT), so
        # delegate.py's subprocess call finds it. It records the raw command line
        # (so `model_reasoning_effort=high` survives intact) and emits a
        # JSON-Lines agent message like `codex exec --json` would.
        function Write-CodexStub {
            $cmd = @(
                '@echo off',
                'echo %* > "%STUB_RECORD%"',
                'echo {"type":"item.completed","item":{"type":"agent_message","text":"Stub review complete: no high-severity findings."}}'
            ) -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:Bin "codex.cmd"), $cmd, (New-Object System.Text.ASCIIEncoding))
        }

        # A stub that exits non-zero, so the adapter's provider-failure path is
        # exercised deterministically — independent of whether a real codex
        # happens to be installed on the test machine.
        function Write-FailingCodexStub {
            $cmd = @('@echo off', 'echo boom 1>&2', 'exit /b 7') -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:Bin "codex.cmd"), $cmd, (New-Object System.Text.ASCIIEncoding))
        }

        # Invoke delegate.ps1 with the stub bin on PATH and STUB_RECORD in env.
        function Invoke-Delegate {
            param([string[]]$Arguments, [switch]$WithStub)
            $delegateScript = Join-Path $script:KitRoot "tooling\shared\delegate\delegate.ps1"
            $oldPath = $env:PATH
            $oldRecord = $env:STUB_RECORD
            try {
                if ($WithStub) { $env:PATH = "$script:Bin;$oldPath" }
                $env:STUB_RECORD = $script:StubRecord
                return Invoke-AakPowerShellScript -Script $delegateScript -Arguments $Arguments
            } finally {
                $env:PATH = $oldPath
                if ($null -eq $oldRecord) { Remove-Item Env:\STUB_RECORD -ErrorAction SilentlyContinue } else { $env:STUB_RECORD = $oldRecord }
            }
        }

        function Get-DelegateEventsFile {
            param([string]$RunId)
            return (Join-Path $script:RuntimePath "runs\$RunId\events.ndjson")
        }
    }

    It "requires a brief file" {
        $delegateScript = Join-Path $script:KitRoot "tooling\shared\delegate\delegate.ps1"
        $result = Invoke-AakPowerShellScript -Script $delegateScript -Arguments @("-Provider", "codex", "-Config", $script:ConfigPath, "-SourceRoot", $script:Target)
        Assert-AakFailure $result
    }

    It "rejects an unsupported provider" {
        $result = Invoke-Delegate -Arguments @("-Provider", "antigravity", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_unsup")
        Assert-AakFailure $result
    }

    It "routes security_review/high to high reasoning effort" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "security_review", "-Risk", "high", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_high")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "Stub review complete"
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("model_reasoning_effort=high")) { throw "expected high effort in argv: $argv" }
        if (-not $argv.Contains("read-only")) { throw "expected read-only sandbox in argv: $argv" }
        if (-not $argv.Contains("--json")) { throw "expected --json in argv: $argv" }
    }

    It "routes formatting/low to low reasoning effort" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "formatting", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_low")
        Assert-AakSuccess $result
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("model_reasoning_effort=low")) { throw "expected low effort in argv: $argv" }
    }

    It "emits agent.selected/invoked/completed with a provider field" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "security_review", "-Risk", "high", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_events", "-InvocationId", "inv_deleg")
        Assert-AakSuccess $result
        $eventsFile = Get-DelegateEventsFile "run_events"
        Assert-AakFileExists $eventsFile
        $types = @(Get-Content $eventsFile | Where-Object { $_.Trim() } | ForEach-Object { ($_ | ConvertFrom-Json).event_type })
        foreach ($need in @("agent.selected", "agent.invoked", "agent.completed")) {
            if ($types -notcontains $need) { throw "missing event $need; got $($types -join ',')" }
        }
        $completed = Get-Content $eventsFile | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.event_type -eq "agent.completed" } | Select-Object -First 1
        if ($completed.payload.provider -ne "codex") { throw "expected provider codex, got $($completed.payload.provider)" }
        if ($completed.payload.status -ne "success") { throw "expected status success, got $($completed.payload.status)" }
    }

    It "skips delegation when the brief fails the privacy scan" {
        # A secret-like token must never reach the provider CLI.
        [System.IO.File]::WriteAllText($script:BriefPath, "leaked secret sk-ABCDEFGHIJKLMNOPqrstuvwx here", (New-Object System.Text.UTF8Encoding($false)))
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "other", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_priv")
        Assert-AakSuccess $result
        Assert-AakFileMissing $script:StubRecord
    }

    It "is fail-open when the provider CLI fails" {
        # The provider exits non-zero: the adapter must not crash; it records an
        # error completion and returns 0 so the orchestrator is undisturbed.
        Write-FailingCodexStub
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "other", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_missing")
        Assert-AakSuccess $result
        $eventsFile = Get-DelegateEventsFile "run_missing"
        Assert-AakFileExists $eventsFile
        $completed = Get-Content $eventsFile | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.event_type -eq "agent.completed" } | Select-Object -First 1
        if ($completed.payload.status -ne "error") { throw "expected status error, got $($completed.payload.status)" }
    }
}
