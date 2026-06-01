Describe "Cross-run rollups (#330)" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        $script:AuditRoot = Join-Path ([System.IO.Path]::GetTempPath()) "aak-rollup-$([guid]::NewGuid().ToString('N'))"
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
                governance = [ordered]@{ target_report_tokens = 1200 }
                push = [ordered]@{ mode = "disabled"; commit = $false }
            }
        }
        [System.IO.File]::WriteAllText($script:ConfigPath, ($config | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $script:Emit = Join-Path $script:KitRoot "tooling\shared\agent-audit\emit-event.ps1"
        $script:Finalize = Join-Path $script:KitRoot "tooling\shared\agent-audit\finalize-run.ps1"
        $script:Rollup = Join-Path $script:KitRoot "tooling\shared\agent-audit\rollup.ps1"
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) { Remove-AakPesterTarget }
        if ($script:AuditRoot -and (Test-Path -LiteralPath $script:AuditRoot)) {
            Remove-Item -LiteralPath $script:AuditRoot -Recurse -Force
        }
    }

    function Invoke-Emit {
        param([string]$RunId, [string]$Type, [string]$Actor, [string]$Payload = "", [string]$InvocationId = "")
        $emitArgs = @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-Type", $Type, "-Actor", $Actor, "-RunId", $RunId)
        if ($Payload) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Payload))
            $emitArgs += @("-PayloadB64", $b64)
        }
        if ($InvocationId) { $emitArgs += @("-InvocationId", $InvocationId) }
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $script:Emit -Arguments $emitArgs)
    }

    function Complete-SeedRun {
        param([string]$RunId)
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $script:Finalize -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target, "-RunId", $RunId))
    }

    It "aggregates across runs by project, agent, and task type" {
        # proj_a run 1: review tier, codex metrics with high context occupancy.
        Invoke-Emit -RunId "run_a1" -Type "run.completed" -Actor "system" -Payload '{"project_hash":"hmac_sha256_proj_a","task_type":"security_review","risk_level":"high","complexity":"large","answered_assigned_task":true,"has_sanitized_evidence":true,"validation_state":"passed","observed_model_tier":"review","report_tokens":800,"status":"completed"}'
        Invoke-Emit -RunId "run_a1" -Type "session.metrics" -Actor "system" -Payload '{"provider":"codex","model":"gpt-5.5","tokens":{"input":900,"output":100,"cache_creation":0,"cache_read":100,"total":1100,"cache_hit_ratio":0.1},"speed":{"avg_tokens_per_sec":50.0,"samples":1},"context":{"context_used_ratio":0.9}}'
        Invoke-Emit -RunId "run_a1" -Type "agent.invoked" -Actor "subagent" -InvocationId "inv_1" -Payload '{"agent_category":"security"}'
        Invoke-Emit -RunId "run_a1" -Type "agent.completed" -Actor "subagent" -InvocationId "inv_1" -Payload '{"status":"success"}'
        Complete-SeedRun -RunId "run_a1"

        # proj_a run 2: fast tier on high-risk review + failed validation + retry -> underpowered.
        Invoke-Emit -RunId "run_a2" -Type "run.completed" -Actor "system" -Payload '{"project_hash":"hmac_sha256_proj_a","task_type":"security_review","risk_level":"high","complexity":"large","answered_assigned_task":false,"has_sanitized_evidence":false,"validation_state":"failed","observed_model_tier":"fast","status":"completed_with_warnings"}'
        Invoke-Emit -RunId "run_a2" -Type "retry.requested" -Actor "main_agent"
        Invoke-Emit -RunId "run_a2" -Type "agent.invoked" -Actor "subagent" -InvocationId "inv_1" -Payload '{"agent_category":"security"}'
        Invoke-Emit -RunId "run_a2" -Type "agent.completed" -Actor "subagent" -InvocationId "inv_1" -Payload '{"status":"success"}'
        Complete-SeedRun -RunId "run_a2"

        # proj_b run: docs update with claude metrics (priced).
        Invoke-Emit -RunId "run_b1" -Type "run.completed" -Actor "system" -Payload '{"project_hash":"hmac_sha256_proj_b","task_type":"docs_update","risk_level":"low","complexity":"trivial","answered_assigned_task":true,"has_sanitized_evidence":true,"validation_state":"passed","observed_model_tier":"deep","report_tokens":700,"status":"completed"}'
        Invoke-Emit -RunId "run_b1" -Type "session.metrics" -Actor "system" -Payload '{"provider":"claude","model":"claude-opus-4-8","tokens":{"input":1000,"output":200,"cache_creation":0,"cache_read":0,"total":1200,"cache_hit_ratio":0.0},"speed":{"avg_tokens_per_sec":70.0,"samples":1},"cost_estimate":{"currency":"USD","amount":0.01,"basis":"list-price-approximation"}}'
        Complete-SeedRun -RunId "run_b1"

        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $script:Rollup -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target))

        $d = Get-Content -Raw (Join-Path $script:CentralPath "agent-audit\rollups\cross-run-rollup.json") | ConvertFrom-Json
        if ($d.run_count -ne 3) { throw "run_count $($d.run_count)" }
        $a = $d.by_project_hash."hmac_sha256_proj_a"
        if ($a.run_count -ne 2) { throw "proj_a run_count $($a.run_count)" }
        if ($a.model_fit_distribution.underpowered -ne 1) { throw "underpowered $($a.model_fit_distribution | ConvertTo-Json -Compress)" }
        if ($a.context_exhaustion.exhausted_run_count -ne 1) { throw "exhausted $($a.context_exhaustion | ConvertTo-Json -Compress)" }
        if ($a.tokens.sum_total -ne 1100) { throw "tokens $($a.tokens | ConvertTo-Json -Compress)" }
        if ($d.by_agent.security.run_count -ne 2) { throw "security agent $($d.by_agent.security.run_count)" }
        if ($d.overall.cost.runs_with_cost -ne 1) { throw "runs_with_cost $($d.overall.cost.runs_with_cost)" }
        if (-not ($d.overall.cost.sum_amount -gt 0)) { throw "cost sum $($d.overall.cost.sum_amount)" }

        Assert-AakFileExists (Join-Path $script:CentralPath "agent-audit\rollups\cross-run-rollup.md")
    }

    It "writes a zero-run rollup when no runs exist" {
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $script:Rollup -Arguments @("-Config", $script:ConfigPath, "-SourceRoot", $script:Target))
        $d = Get-Content -Raw (Join-Path $script:CentralPath "agent-audit\rollups\cross-run-rollup.json") | ConvertFrom-Json
        if ($d.run_count -ne 0) { throw "run_count $($d.run_count)" }
        Assert-AakFileExists (Join-Path $script:CentralPath "agent-audit\rollups\cross-run-rollup.md")
    }
}
