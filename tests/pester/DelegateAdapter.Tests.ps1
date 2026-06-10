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
        Write-AgyStub
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

        function Write-EmptyCodexStub {
            $cmd = @('@echo off', 'exit /b 0') -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:Bin "codex.cmd"), $cmd, (New-Object System.Text.ASCIIEncoding))
        }

        function Write-SkippedCodexStub {
            $cmd = @('@echo off', 'exit /b 127') -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:Bin "codex.cmd"), $cmd, (New-Object System.Text.ASCIIEncoding))
        }

        # An agy stub that simulates quota exhaustion on the primary (Opus) model:
        # exits non-zero with a 429-like error so the adapter's fallback path fires,
        # then succeeds when the fallback model (gemini-3.1-pro) is selected.
        function Write-QuotaAgyStub {
            $cmd = @(
                '@echo off',
                'set "model="',
                ':record_args',
                'if "%~1"=="" goto run',
                'echo %~1>> "%STUB_RECORD%"',
                'if "%~1"=="-m" set "model=%~2"',
                'shift',
                'goto record_args',
                ':run',
                'if "%model%"=="claude-opus-4-6" (',
                '    echo Error: 429 quota exhausted for claude-opus-4-6 1>&2',
                '    exit /b 1',
                ')',
                'echo {"response":"Stub Antigravity fallback analysis: succeeded with fallback model."}'
            ) -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:Bin "agy.cmd"), $cmd, (New-Object System.Text.ASCIIEncoding))
        }

        # Antigravity stub: records argv one argument per line, then prints JSON
        # like `agy --output-format json` would.
        function Write-AgyStub {
            $cmd = @(
                '@echo off',
                'type nul > "%STUB_RECORD%"',
                ':record_args',
                'if "%~1"=="" goto respond',
                'echo %~1>> "%STUB_RECORD%"',
                'shift',
                'goto record_args',
                ':respond',
                'echo {"response":"Stub Antigravity analysis: no blocking issue."}'
            ) -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:Bin "agy.cmd"), $cmd, (New-Object System.Text.ASCIIEncoding))
        }

        # Invoke delegate.ps1 with the stub bin on PATH and STUB_RECORD in the
        # environment.
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

    }

    It "requires a brief file" {
        $delegateScript = Join-Path $script:KitRoot "tooling\shared\delegate\delegate.ps1"
        $result = Invoke-AakPowerShellScript -Script $delegateScript -Arguments @("-Provider", "codex", "-Config", $script:ConfigPath, "-SourceRoot", $script:Target)
        Assert-AakFailure $result
    }

    It "rejects an unsupported provider" {
        $result = Invoke-Delegate -Arguments @("-Provider", "gemini", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_unsup")
        Assert-AakFailure $result
    }

    It "routes security_review/high to high reasoning effort" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "security_review", "-Risk", "high", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_high")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "Stub review complete"
        Assert-AakOutputContains $result "delegate-status: status=ok"
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

    It "routes investigation/medium to the Antigravity Opus model" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "investigation", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_deep")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "Stub Antigravity analysis"
        Assert-AakOutputContains $result "antigravity invoking model 'claude-opus-4-6'"
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("-m")) { throw "expected -m in argv: $argv" }
        if (-not $argv.Contains("claude-opus-4-6")) { throw "expected Opus model in argv: $argv" }
        if (-not $argv.Contains("--output-format")) { throw "expected --output-format in argv: $argv" }
        if (-not $argv.Contains("json")) { throw "expected json output format in argv: $argv" }
        if (-not $argv.Contains("--sandbox")) { throw "expected --sandbox in argv: $argv" }
        if ($argv.Contains("--dangerously-skip-permissions")) { throw "expected no skip-permissions in read-only argv: $argv" }
    }

    It "routes daily/medium to the Antigravity Sonnet model" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "daily", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_std")
        Assert-AakSuccess $result
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("claude-sonnet-4-6")) { throw "expected Sonnet model in argv: $argv" }
    }

    It "AAK_DEBUG=1 prints resolved provider/depth/model before exec (#477)" {
        $env:AAK_DEBUG = "1"
        try {
            $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "investigation", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_dbg1")
            Assert-AakSuccess $result
            Assert-AakOutputContains $result "AAK_DEBUG provider=antigravity"
            Assert-AakOutputContains $result "depth=deep"
            Assert-AakOutputContains $result "model=claude-opus-4-6"
        } finally {
            Remove-Item Env:AAK_DEBUG -ErrorAction SilentlyContinue
        }
    }

    It "AAK_DEBUG=0 keeps the delegate debug line off (#477)" {
        $env:AAK_DEBUG = "0"
        try {
            $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "investigation", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_dbg0")
            Assert-AakSuccess $result
            if ($result.Output.Contains("AAK_DEBUG provider=")) { throw "expected no AAK_DEBUG line: $($result.Output)" }
        } finally {
            Remove-Item Env:AAK_DEBUG -ErrorAction SilentlyContinue
        }
    }

    It "uses workspace-write sandbox for Codex implementation tasks" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "feat", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_codex_impl")
        Assert-AakSuccess $result
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("workspace-write")) { throw "expected workspace-write sandbox in argv: $argv" }
        if ($argv.Contains("read-only")) { throw "expected no read-only in impl argv: $argv" }
    }

    It "drops --sandbox for Antigravity implementation tasks" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "feat", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_impl")
        Assert-AakSuccess $result
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("--dangerously-skip-permissions")) { throw "expected skip-permissions in argv: $argv" }
        if ($argv.Contains("--sandbox")) { throw "expected no --sandbox in impl argv: $argv" }
    }

    It "omits --dangerously-skip-permissions for read-only Antigravity tasks (#476)" {
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "investigation", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_ro")
        Assert-AakSuccess $result
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("--sandbox")) { throw "expected --sandbox in read-only argv: $argv" }
        if ($argv.Contains("--dangerously-skip-permissions")) { throw "expected no skip-permissions in read-only argv: $argv" }
    }

    It "redacts secret-like tokens in the brief and still delegates" {
        # A secret-like token must be redacted before it reaches the provider,
        # but delegation still proceeds with the redacted brief.
        $secret = "sk-ABCDEFGHIJKLMNOPqrstuvwx"
        [System.IO.File]::WriteAllText($script:BriefPath, "leaked secret $secret here", (New-Object System.Text.UTF8Encoding($false)))
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "other", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_priv")
        Assert-AakSuccess $result
        if (-not (Test-Path -LiteralPath $script:StubRecord)) { throw "expected the provider to be invoked (StubRecord missing)" }
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("[REDACTED_")) { throw "expected a redaction marker in argv: $argv" }
        if ($argv.Contains($secret)) { throw "raw secret leaked to provider argv: $argv" }
    }

    It "retries with Gemini fallback when Antigravity Opus quota is exhausted" {
        Write-QuotaAgyStub
        [System.IO.File]::WriteAllText($script:StubRecord, "", (New-Object System.Text.UTF8Encoding($false)))
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "antigravity", "-TaskType", "investigation", "-Risk", "high", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy_fallback")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "fallback analysis"
        $argv = Get-Content -Raw $script:StubRecord
        if (-not $argv.Contains("claude-opus-4-6")) { throw "expected Opus primary model in accumulated argv: $argv" }
        if (-not $argv.Contains("gemini-3.1-pro")) { throw "expected Gemini fallback model in accumulated argv: $argv" }
        # Audit event emission removed (#408) — emit() is now a no-op.
    }

    It "does not retry fallback for Codex quota errors" {
        # Codex has no per-model fallback path; a quota error is an ordinary
        # provider failure that records status=error and returns 0.
        Write-FailingCodexStub
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "feat", "-Risk", "medium", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_codex_quota")
        Assert-AakSuccess $result
        # Codex quota errors are fail-open: adapter returns 0 so the orchestrator is undisturbed.
        # Audit event emission removed (#408) — emit() is now a no-op.
    }

    It "reports an empty provider summary" {
        Write-EmptyCodexStub
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "other", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_empty")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "delegate-status: status=empty"
    }

    It "reports a skipped provider" {
        Write-SkippedCodexStub
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "other", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_skipped")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "delegate-status: status=skipped"
    }

    It "is fail-open when the provider CLI fails" {
        # The provider exits non-zero: the adapter must not crash; it records an
        # error completion and returns 0 so the orchestrator is undisturbed.
        Write-FailingCodexStub
        $result = Invoke-Delegate -WithStub -Arguments @("-Provider", "codex", "-TaskType", "other", "-Risk", "low", "-BriefFile", $script:BriefPath, "-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_missing")
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "delegate-status: status=error"
        # Provider failure is fail-open: adapter returns 0 so the orchestrator is undisturbed.
        # Audit event emission removed (#408) — emit() is now a no-op.
    }
}
