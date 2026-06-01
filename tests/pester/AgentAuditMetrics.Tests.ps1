Describe "Session-metrics import (#327)" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        $script:AuditRoot = Join-Path ([System.IO.Path]::GetTempPath()) "aak-metrics-$([guid]::NewGuid().ToString('N'))"
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

        # Transcript with deliberately forbidden data (content/cwd/gitBranch).
        $script:Transcript = Join-Path $script:AuditRoot "t.jsonl"
        $lines = @'
{"type":"user","timestamp":"2026-05-31T10:00:00Z","cwd":"/Users/zzleakzz/p","gitBranch":"feature/zzleakzz","message":{"role":"user","content":"zzleakzz prompt"}}
{"type":"assistant","timestamp":"2026-05-31T10:00:05Z","message":{"role":"assistant","model":"claude-opus-4-7","content":[{"type":"text","text":"zzleakzz answer"}],"usage":{"input_tokens":1000,"output_tokens":200,"cache_creation_input_tokens":50,"cache_read_input_tokens":4000,"speed":90.0}}}
{"type":"assistant","timestamp":"2026-05-31T10:00:09Z","isSidechain":true,"message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":300,"output_tokens":90,"cache_read_input_tokens":1000,"speed":110.0}}}
{"type":"system","subtype":"compact_boundary","timestamp":"2026-05-31T10:00:20Z"}
'@
        [System.IO.File]::WriteAllText($script:Transcript, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) { Remove-AakPesterTarget }
        if ($script:AuditRoot -and (Test-Path -LiteralPath $script:AuditRoot)) {
            Remove-Item -LiteralPath $script:AuditRoot -Recurse -Force
        }
    }

    It "imports anonymized metrics and never leaks raw content" {
        $emit = Join-Path $script:KitRoot "tooling\shared\agent-audit\emit-event.ps1"
        $import = Join-Path $script:KitRoot "tooling\shared\agent-audit\import-session-metrics.ps1"
        $finalize = Join-Path $script:KitRoot "tooling\shared\agent-audit\finalize-run.ps1"
        $payload = '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))

        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $emit -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Type", "run.completed", "-Actor", "system", "-RunId", "run_metrics", "-PayloadB64", $b64))
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $import -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Provider", "claude", "-Transcript", $script:Transcript, "-RunId", "run_metrics"))
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $finalize -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_metrics"))

        # emit/import stamp events with the real current time, so the year/month
        # path segments are not hardcodable; locate the run folder by name.
        $base = (Get-ChildItem -Path (Join-Path $script:CentralPath "agent-audit\runs") -Recurse -Directory -Filter "run_metrics" | Select-Object -First 1).FullName
        if (-not $base) { throw "run folder run_metrics not found under central runs" }
        $tc = Get-Content -Raw (Join-Path $base "token-context.json") | ConvertFrom-Json
        if ($tc.measurement_mode -ne "imported-transcript") { throw "measurement_mode $($tc.measurement_mode)" }
        if ($tc.tokens.input -ne 1300) { throw "input $($tc.tokens.input)" }
        if ($tc.tokens.output -ne 290) { throw "output $($tc.tokens.output)" }
        if ($tc.tokens.cache_read -ne 5000) { throw "cache_read $($tc.tokens.cache_read)" }
        if ($tc.subagent.sidechain_output_tokens -ne 90) { throw "sidechain $($tc.subagent.sidechain_output_tokens)" }
        if ($tc.compression.executed_count -ne 1) { throw "compaction $($tc.compression.executed_count)" }
        $pr = Get-Content -Raw (Join-Path $base "pricing-estimate.json") | ConvertFrom-Json
        if ($pr.measurement_mode -ne "list-price-approximation" -or -not ($pr.amount -gt 0)) { throw "pricing $($pr | ConvertTo-Json -Compress)" }

        $leak = Get-ChildItem -LiteralPath $base, $script:RuntimePath -Recurse -File |
            Select-String -Pattern "zzleakzz" -SimpleMatch -List
        if ($leak) { throw "raw content leaked: $($leak.Path -join ', ')" }
    }

    It "fails without a run id" {
        $import = Join-Path $script:KitRoot "tooling\shared\agent-audit\import-session-metrics.ps1"
        $result = Invoke-AakPowerShellScript -Script $import -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Provider", "claude", "-Transcript", $script:Transcript)
        Assert-AakFailure $result
    }

    It "imports codex token_count metrics and never leaks raw content" {
        $emit = Join-Path $script:KitRoot "tooling\shared\agent-audit\emit-event.ps1"
        $import = Join-Path $script:KitRoot "tooling\shared\agent-audit\import-session-metrics.ps1"
        $finalize = Join-Path $script:KitRoot "tooling\shared\agent-audit\finalize-run.ps1"
        $codex = Join-Path $script:AuditRoot "codex.jsonl"
        # cwd/prompt/answer are forbidden data; a post-compaction counter reset
        # (1120 -> 500 -> 900) exercises segment summing.
        $lines = @'
{"type":"session_meta","timestamp":"2026-05-31T10:00:00Z","payload":{"id":"x","cwd":"/Users/zzleakzz/p","model_provider":"openai"}}
{"type":"turn_context","timestamp":"2026-05-31T10:00:01Z","payload":{"model":"gpt-5.5","cwd":"/Users/zzleakzz/p"}}
{"type":"response_item","timestamp":"2026-05-31T10:00:02Z","payload":{"type":"message","role":"user","content":"zzleakzz prompt"}}
{"type":"response_item","timestamp":"2026-05-31T10:00:03Z","payload":{"type":"function_call","name":"shell"}}
{"type":"response_item","timestamp":"2026-05-31T10:00:04Z","payload":{"type":"function_call_output"}}
{"type":"response_item","timestamp":"2026-05-31T10:00:05Z","payload":{"type":"reasoning"}}
{"type":"response_item","timestamp":"2026-05-31T10:00:06Z","payload":{"type":"message","role":"assistant","content":"zzleakzz answer"}}
{"type":"event_msg","timestamp":"2026-05-31T10:00:07Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":400,"output_tokens":120,"reasoning_output_tokens":50,"total_tokens":1120},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":400,"output_tokens":120,"reasoning_output_tokens":50,"total_tokens":1120},"model_context_window":200000},"rate_limits":{"primary":{"used_percent":75.0,"window_minutes":300},"secondary":{"used_percent":20.0,"window_minutes":10080}}}}
{"type":"event_msg","timestamp":"2026-05-31T10:00:08Z","payload":{"type":"context_compacted"}}
{"type":"event_msg","timestamp":"2026-05-31T10:00:09Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":450,"cached_input_tokens":100,"output_tokens":50,"reasoning_output_tokens":20,"total_tokens":500},"last_token_usage":{"input_tokens":450,"cached_input_tokens":100,"output_tokens":50,"reasoning_output_tokens":20,"total_tokens":500},"model_context_window":200000},"rate_limits":{"primary":{"used_percent":90.0,"window_minutes":300}}}}
{"type":"event_msg","timestamp":"2026-05-31T10:00:10Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":800,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":40,"total_tokens":900},"last_token_usage":{"input_tokens":800,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":40,"total_tokens":900},"model_context_window":200000},"rate_limits":{"primary":{"used_percent":85.0,"window_minutes":300}}}}
'@
        [System.IO.File]::WriteAllText($codex, $lines, (New-Object System.Text.UTF8Encoding($false)))
        $payload = '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))

        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $emit -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Type", "run.completed", "-Actor", "system", "-RunId", "run_codex", "-PayloadB64", $b64))
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $import -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Provider", "codex", "-Transcript", $codex, "-RunId", "run_codex"))
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $finalize -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_codex"))

        $base = (Get-ChildItem -Path (Join-Path $script:CentralPath "agent-audit\runs") -Recurse -Directory -Filter "run_codex" | Select-Object -First 1).FullName
        if (-not $base) { throw "run folder run_codex not found under central runs" }
        $tc = Get-Content -Raw (Join-Path $base "token-context.json") | ConvertFrom-Json
        if ($tc.provider -ne "codex" -or $tc.model -ne "gpt-5.5") { throw "provider/model $($tc.provider)/$($tc.model)" }
        if ($tc.measurement_mode -ne "imported-transcript") { throw "mode $($tc.measurement_mode)" }
        if ($tc.tokens.input -ne 1200) { throw "input $($tc.tokens.input)" }
        if ($tc.tokens.cache_read -ne 600) { throw "cache_read $($tc.tokens.cache_read)" }
        if ($tc.tokens.output -ne 220) { throw "output $($tc.tokens.output)" }
        if ($tc.tokens.total -ne 2020) { throw "total $($tc.tokens.total)" }
        if ($tc.reasoning.output_tokens -ne 90) { throw "reasoning $($tc.reasoning.output_tokens)" }
        if ($tc.rate_limit.primary_used_percent -ne 90) { throw "rate $($tc.rate_limit.primary_used_percent)" }
        if ($tc.context.peak_request_input_tokens -ne 1000) { throw "ctx $($tc.context.peak_request_input_tokens)" }
        if ($tc.compression.executed_count -ne 1) { throw "compaction $($tc.compression.executed_count)" }
        $pr = Get-Content -Raw (Join-Path $base "pricing-estimate.json") | ConvertFrom-Json
        if ($pr.measurement_mode -ne "unavailable") { throw "pricing $($pr.measurement_mode)" }

        $leak = Get-ChildItem -LiteralPath $base, $script:RuntimePath -Recurse -File |
            Select-String -Pattern "zzleakzz" -SimpleMatch -List
        if ($leak) { throw "raw content leaked: $($leak.Path -join ', ')" }
    }

    It "imports antigravity structural metrics only and never leaks" {
        $py = $null
        foreach ($c in @('python', 'python3', 'py')) {
            $g = Get-Command $c -ErrorAction SilentlyContinue
            if ($g) { $py = $g.Source; break }
        }
        if (-not $py) { Set-ItResult -Skipped -Because "python is required to build the SQLite fixture"; return }

        $emit = Join-Path $script:KitRoot "tooling\shared\agent-audit\emit-event.ps1"
        $import = Join-Path $script:KitRoot "tooling\shared\agent-audit\import-session-metrics.ps1"
        $finalize = Join-Path $script:KitRoot "tooling\shared\agent-audit\finalize-run.ps1"
        $db = Join-Path $script:AuditRoot "agy.db"
        $builder = Join-Path $script:AuditRoot "build_agy.py"
        # protobuf BLOBs carrying the model enum string plus forbidden bytes.
        $pyScript = @'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1]); cur = con.cursor()
cur.execute("CREATE TABLE steps (idx INTEGER, step_type INTEGER, step_payload BLOB)")
for i in range(3):
    cur.execute("INSERT INTO steps VALUES (?,?,?)", (i, 1, b"zzleakzz step"))
cur.execute("CREATE TABLE gen_metadata (idx INTEGER, data BLOB, size INTEGER)")
for i in range(2):
    cur.execute("INSERT INTO gen_metadata VALUES (?,?,?)", (i, b"model_enum\x00gemini-3-flash\x00zzleakzz", 10))
cur.execute("CREATE TABLE executor_metadata (idx INTEGER, data BLOB)")
cur.execute("INSERT INTO executor_metadata VALUES (0,?)", (b"exec\x00gemini-3-flash-low\x00zzleakzz",))
con.commit(); con.close()
'@
        [System.IO.File]::WriteAllText($builder, $pyScript, (New-Object System.Text.UTF8Encoding($false)))
        & $py $builder $db | Out-Null
        if (-not (Test-Path -LiteralPath $db)) { throw "fixture db not created" }
        $payload = '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))

        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $emit -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Type", "run.completed", "-Actor", "system", "-RunId", "run_agy", "-PayloadB64", $b64))
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $import -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Provider", "antigravity", "-Transcript", $db, "-RunId", "run_agy"))
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $finalize -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", "run_agy"))

        $base = (Get-ChildItem -Path (Join-Path $script:CentralPath "agent-audit\runs") -Recurse -Directory -Filter "run_agy" | Select-Object -First 1).FullName
        if (-not $base) { throw "run folder run_agy not found under central runs" }
        $tc = Get-Content -Raw (Join-Path $base "token-context.json") | ConvertFrom-Json
        if ($tc.provider -ne "antigravity") { throw "provider $($tc.provider)" }
        if ($tc.model -ne "gemini-3-flash-low") { throw "model $($tc.model)" }
        if ($tc.measurement_mode -ne "imported-transcript-structural") { throw "mode $($tc.measurement_mode)" }
        if ($tc.provider_usage_available -ne $false) { throw "usage $($tc.provider_usage_available)" }
        if ($tc.tokens.total -ne 0) { throw "total $($tc.tokens.total)" }
        if ($tc.context.step_count -ne 3) { throw "steps $($tc.context.step_count)" }
        if ($tc.context.generation_count -ne 2) { throw "gens $($tc.context.generation_count)" }

        $leak = Get-ChildItem -LiteralPath $base, $script:RuntimePath -Recurse -File |
            Select-String -Pattern "zzleakzz" -SimpleMatch -List
        if ($leak) { throw "raw content leaked: $($leak.Path -join ', ')" }
    }
}
