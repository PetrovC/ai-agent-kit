Describe "Lifecycle auto-emit from hooks (#328)" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        $script:AuditRoot = Join-Path ([System.IO.Path]::GetTempPath()) "aak-life-$([guid]::NewGuid().ToString('N'))"
        $script:RuntimePath = Join-Path $script:AuditRoot "runtime"
        $script:CentralPath = Join-Path $script:AuditRoot "central"
        $script:ConfigPath = Join-Path $script:AuditRoot "config.json"
        New-Item -ItemType Directory -Path $script:RuntimePath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:CentralPath -Force | Out-Null
        & git -C $script:CentralPath init | Out-Null
        & git -C $script:CentralPath checkout -b agent-audit-data | Out-Null
        & git -C $script:CentralPath config user.email "audit-test@example.com" | Out-Null
        & git -C $script:CentralPath config user.name "Audit Test" | Out-Null
        $config = [ordered]@{
            schema_version = "0.1.0"
            audit = [ordered]@{
                enabled = $true; mode = "official-central-repo"
                official_remote_url = "https://github.com/PetrovC/ai-agent-kit.git"
                branch = "agent-audit-data"; runtime_path = $script:RuntimePath
                central_repo_path = $script:CentralPath; source_project_write_policy = "never"
                push = [ordered]@{ mode = "disabled"; commit = $false }
            }
        }
        [System.IO.File]::WriteAllText($script:ConfigPath, ($config | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) { Remove-AakPesterTarget }
        if ($script:AuditRoot -and (Test-Path -LiteralPath $script:AuditRoot)) {
            Remove-Item -LiteralPath $script:AuditRoot -Recurse -Force
        }
    }

    It "claude SessionEnd finalizes a run on Windows (CRLF-safe) and never leaks" {
        $bash = Get-Command bash -ErrorAction SilentlyContinue
        if (-not $bash) { Set-ItResult -Skipped -Because "bash is required to run the hook scripts"; return }
        $kit = ($script:KitRoot -replace '\\', '/')
        $hook = "$kit/tooling/claude/hooks/agent-audit-event.sh"
        $env:CLAUDE_PROJECT_DIR = $kit
        $env:AAK_AUDIT_CONFIG = ($script:ConfigPath -replace '\\', '/')
        $env:AAK_AUDIT_RUN_ID = "run_life_ps"
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCmd) { $env:PYTHON = $pythonCmd.Source }
        try {
            '{}' | & bash $hook SessionStart
            '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"echo zzleakzz /Users/zzleakzz"}}' | & bash $hook
            '{}' | & bash $hook SubagentStop
            '{}' | & bash $hook SessionEnd
        } finally {
            Remove-Item Env:CLAUDE_PROJECT_DIR, Env:AAK_AUDIT_CONFIG, Env:AAK_AUDIT_RUN_ID, Env:PYTHON -ErrorAction SilentlyContinue
        }

        $base = Get-ChildItem -LiteralPath $script:CentralPath -Recurse -Directory -Filter "run_life_ps" | Select-Object -First 1
        if (-not $base) { throw "run was not finalized on session end (CRLF regression in the run.completed compare?)" }
        $events = Get-Content -Raw (Join-Path $base.FullName "governance-events.ndjson")
        if ($events -notmatch '"event_type":"run.started"') { throw "missing run.started" }
        if ($events -notmatch '"event_type":"run.completed"') { throw "missing run.completed" }

        $leak = Get-ChildItem -LiteralPath $base.FullName, $script:RuntimePath -Recurse -File |
            Select-String -Pattern "zzleakzz" -SimpleMatch -List
        if ($leak) { throw "raw content leaked: $($leak.Path -join ', ')" }
    }

    It "claude SessionEnd auto-imports anonymized session metrics from the transcript" {
        $bash = Get-Command bash -ErrorAction SilentlyContinue
        if (-not $bash) { Set-ItResult -Skipped -Because "bash is required to run the hook scripts"; return }
        $kit = ($script:KitRoot -replace '\\', '/')
        $hook = "$kit/tooling/claude/hooks/agent-audit-event.sh"
        $transcript = Join-Path $script:AuditRoot "session.jsonl"
        $lines = @'
{"type":"user","timestamp":"2026-06-01T10:00:00Z","cwd":"/Users/zzleakzz/p","message":{"role":"user","content":"zzleakzz prompt"}}
{"type":"assistant","timestamp":"2026-06-01T10:00:05Z","message":{"role":"assistant","model":"claude-opus-4-8","content":[{"type":"text","text":"zzleakzz answer"}],"usage":{"input_tokens":1000,"output_tokens":200,"cache_read_input_tokens":4000,"speed":90.0}}}
'@
        [System.IO.File]::WriteAllText($transcript, $lines, (New-Object System.Text.UTF8Encoding($false)))
        $tpath = ($transcript -replace '\\', '/')
        $env:CLAUDE_PROJECT_DIR = $kit
        $env:AAK_AUDIT_CONFIG = ($script:ConfigPath -replace '\\', '/')
        $env:AAK_AUDIT_RUN_ID = "run_metrics_ps"
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCmd) { $env:PYTHON = $pythonCmd.Source }
        try {
            "{`"transcript_path`":`"$tpath`"}" | & bash $hook SessionEnd
        } finally {
            Remove-Item Env:CLAUDE_PROJECT_DIR, Env:AAK_AUDIT_CONFIG, Env:AAK_AUDIT_RUN_ID, Env:PYTHON -ErrorAction SilentlyContinue
        }

        $base = Get-ChildItem -LiteralPath $script:CentralPath -Recurse -Directory -Filter "run_metrics_ps" | Select-Object -First 1
        if (-not $base) { throw "run was not finalized on session end" }
        $tc = Get-Content -Raw (Join-Path $base.FullName "token-context.json") | ConvertFrom-Json
        if ($tc.measurement_mode -ne "imported-transcript") { throw "measurement_mode $($tc.measurement_mode)" }
        if ($tc.tokens.total -ne 5200) { throw "tokens.total $($tc.tokens.total)" }
        if ($tc.tokens.cache_hit_ratio -ne 0.8) { throw "cache_hit_ratio $($tc.tokens.cache_hit_ratio)" }

        $leak = Get-ChildItem -LiteralPath $base.FullName, $script:RuntimePath -Recurse -File |
            Select-String -Pattern "zzleakzz" -SimpleMatch -List
        if ($leak) { throw "raw content leaked: $($leak.Path -join ', ')" }
    }
}
