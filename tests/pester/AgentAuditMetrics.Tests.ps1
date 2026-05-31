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

        $base = Join-Path $script:CentralPath "agent-audit\runs\2026\05\hmac_sha256_example_project\run_metrics"
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
}
