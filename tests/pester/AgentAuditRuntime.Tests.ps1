Describe "PowerShell agent audit runtime" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        $script:AuditRoot = Join-Path ([System.IO.Path]::GetTempPath()) "aak-audit-runtime-$([guid]::NewGuid().ToString('N'))"
        $script:RuntimePath = Join-Path $script:AuditRoot "runtime"
        $script:CentralPath = Join-Path $script:AuditRoot "central"
        New-Item -ItemType Directory -Path $script:RuntimePath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:CentralPath -Force | Out-Null
        & git -C $script:CentralPath init | Out-Null
        & git -C $script:CentralPath checkout -b agent-audit-data | Out-Null
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
        if ($script:AuditRoot -and (Test-Path -LiteralPath $script:AuditRoot)) {
            Remove-Item -LiteralPath $script:AuditRoot -Recurse -Force
        }
    }

    BeforeAll {
        function Write-AuditConfig {
            param([string]$Path)

            $config = [ordered]@{
                schema_version = "0.1.0"
                audit = [ordered]@{
                    enabled = $true
                    mode = "official-central-repo"
                    official_remote_url = "https://github.com/PetrovC/ai-agent-kit.git"
                    branch = "agent-audit-data"
                    runtime_path = $script:RuntimePath
                    central_repo_path = $script:CentralPath
                    source_project_write_policy = "never"
                    anonymization = [ordered]@{
                        salt_scope = "local-only"
                        drop_raw_content = $true
                        forbid_exact_paths = $true
                        forbid_repository_urls = $true
                        forbid_branch_names = $true
                    }
                    push = [ordered]@{
                        mode = "disabled"
                        commit = $false
                        unauthorized_fallback = "local-outbox"
                    }
                }
            }
            $json = $config | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
        }

        function Write-AuditEvent {
            param(
                [string]$Path,
                [string]$RunId = "run_20260528_120000_test",
                [int]$Sequence = 1,
                [hashtable]$Payload = @{
                    project_hash = "hmac_sha256_example_project"
                    task_type = "feature_implementation"
                    technical_scopes = @("tooling", "tests")
                    status = "completed"
                    validation_state = "passed"
                },
                [string]$EventType = "run.completed"
            )

            $event = [ordered]@{
                schema_version = "0.1.0"
                event_id = "evt_$Sequence"
                audit_run_id = $RunId
                sequence = $Sequence
                occurred_at = "2026-05-28T12:00:00Z"
                event_type = $EventType
                actor_kind = "system"
                invocation_id = $null
                payload = $Payload
            }
            $json = $event | ConvertTo-Json -Depth 10 -Compress
            [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
        }
    }

    It "records sanitized events outside the source project" {
        $configPath = Join-Path $script:AuditRoot "config.json"
        $eventPath = Join-Path $script:AuditRoot "event.json"
        Write-AuditConfig $configPath
        Write-AuditEvent $eventPath

        $recordScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\record-event.ps1"
        $result = Invoke-AakPowerShellScript -Script $recordScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-EventFile", $eventPath)

        Assert-AakSuccess $result
        $eventsPath = Join-Path $script:RuntimePath "runs\run_20260528_120000_test\events.ndjson"
        Assert-AakFileExists $eventsPath
        if ($eventsPath.StartsWith($script:Target, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Runtime event stream was written inside the source project"
        }
    }

    It "rejects unsafe raw-content fields before writing" {
        $configPath = Join-Path $script:AuditRoot "config.json"
        $eventPath = Join-Path $script:AuditRoot "unsafe-event.json"
        Write-AuditConfig $configPath
        Write-AuditEvent -Path $eventPath -Payload @{ prompt = "raw user prompt" }

        $recordScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\record-event.ps1"
        $result = Invoke-AakPowerShellScript -Script $recordScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-EventFile", $eventPath)

        Assert-AakFailure $result
        Assert-AakFileMissing (Join-Path $script:RuntimePath "runs\run_20260528_120000_test\events.ndjson")
    }

    It "rejects path traversal run identifiers" {
        $configPath = Join-Path $script:AuditRoot "config.json"
        $eventPath = Join-Path $script:AuditRoot "unsafe-run-id.json"
        Write-AuditConfig $configPath
        Write-AuditEvent -Path $eventPath -RunId ".."

        $recordScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\record-event.ps1"
        $result = Invoke-AakPowerShellScript -Script $recordScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-EventFile", $eventPath)

        Assert-AakFailure $result
        Assert-AakFileMissing (Join-Path $script:RuntimePath "events.ndjson")
    }

    It "finalizes a run into the central audit branch" {
        $configPath = Join-Path $script:AuditRoot "config.json"
        $eventPath = Join-Path $script:AuditRoot "event.json"
        $runId = "run_20260528_120000_test"
        Write-AuditConfig $configPath
        Write-AuditEvent -Path $eventPath -RunId $runId

        $recordScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\record-event.ps1"
        $finalizeScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\finalize-run.ps1"
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $recordScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-EventFile", $eventPath))

        $result = Invoke-AakPowerShellScript -Script $finalizeScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-RunId", $runId)

        Assert-AakSuccess $result
        $summary = Join-Path $script:CentralPath "agent-audit\runs\2026\05\hmac_sha256_example_project\$runId\run-summary.json"
        Assert-AakFileExists $summary
    }

    It "refuses to finalize on a non-audit branch" {
        $configPath = Join-Path $script:AuditRoot "config.json"
        $eventPath = Join-Path $script:AuditRoot "event.json"
        $runId = "run_20260528_120000_branch_test"
        Write-AuditConfig $configPath
        Write-AuditEvent -Path $eventPath -RunId $runId

        $recordScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\record-event.ps1"
        $finalizeScript = Join-Path $script:KitRoot "tooling\shared\agent-audit\finalize-run.ps1"
        Assert-AakSuccess (Invoke-AakPowerShellScript -Script $recordScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-EventFile", $eventPath))
        & git -C $script:CentralPath checkout -b master | Out-Null

        $result = Invoke-AakPowerShellScript -Script $finalizeScript -Arguments @("-Config", $configPath, "-SourceRoot", $script:Target, "-RunId", $runId)

        Assert-AakFailure $result
        Assert-AakFileMissing (Join-Path $script:CentralPath "agent-audit\runs\2026\05\hmac_sha256_example_project\$runId\run-summary.json")
    }
}
