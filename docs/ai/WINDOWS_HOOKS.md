# Windows Hook Setup Guidance

Claude Code hooks (such as `pre-bash-guard`, etc.) are shell scripts designed to run under Git Bash or WSL on Windows. Since Windows environments can resolve `bash` in different, sometimes conflicting ways, this guide outlines how to ensure hooks execute correctly.

## Why Git Bash or WSL Bash is Required

On Windows, the system must resolve `bash` to a real bash environment like Git Bash or WSL bash. It must **NOT** resolve to the Microsoft Store's app-execution alias (which is a dummy executable that opens the store if WSL/Ubuntu is not installed, or fails when called programmatically).

## Verifying Your Bash Installation

To check what `bash` executable resolves to in the terminal where you run Claude Code, execute:

```bash
bash --version
```

- **Correct Output:** Should display GNU bash version information (e.g., `GNU bash, version 5.x...`).
- **Incorrect Output:** If it opens the Microsoft Store, prints an alias error, or command not found, the terminal is resolving to the Windows Store app-execution alias.

You can also run a quick command check:
```bash
bash -c "echo ok"
```
It must print `ok`. If it fails or does nothing, you need to update your path or default shell settings.

## WSL Path and Configuration

In some Windows setups, `bash.exe` resolves to the WSL launcher stub at
`%windir%\System32\bash.exe`.

- **This does not work for the kit's hooks.** The hooks invoke
  `bash "C:\...\hook.sh"` with a Windows-style path argument, which a WSL distro
  cannot read without `/mnt/c` translation. If no WSL distro is installed the
  stub also prints *"Windows Subsystem for Linux has no installed distributions"*
  and exits non-zero. Either way the `pre-bash-guard` PreToolUse hook silently
  never runs, so destructive-command interception is lost without any visible
  signal — matching the **"Does not work"** characterization in the README.
- **Fix:** put real Git Bash (`%ProgramFiles%\Git\bin\bash.exe`) ahead of
  `%SystemRoot%\System32` on `PATH`, or use the `run-hook.ps1` wiring described
  under [Contributing to ai-agent-kit from Windows](#contributing-to-ai-agent-kit-from-windows).

## Setting the Default Shell in VS Code

If you run Claude Code inside VS Code's integrated terminal, make sure the default profile is configured to use Git Bash (or another real shell) instead of CMD or PowerShell if your path defaults are problematic.

To configure this in VS Code:
1. Open Settings (`Ctrl + ,`).
2. Search for `terminal.integrated.defaultProfile.windows`.
3. Set the value to `"Git Bash"` (or configure it in your `settings.json`):

```json
"terminal.integrated.defaultProfile.windows": "Git Bash"
```

## PowerShell Execution Policy for PowerShell Hooks

Some hooks or tasks run PowerShell wrapper scripts (e.g., `run-hook.ps1`). These require a relaxed execution policy to run without security prompts.
- This is already configured in the repository's `settings.windows.json` by specifying `-ExecutionPolicy Bypass`.
- If you run PowerShell hooks manually outside this setup, ensure you run them with `-ExecutionPolicy Bypass`.

## Switching Shells Safely

Do not change the terminal shell type or profile while a Claude Code session is active.
- Changing the shell mid-session can cause environment variables to mismatch or disrupt child processes running hooks.
- If you need to switch shells, exit the Claude Code session (`/exit` or `Ctrl + D`), change the shell in your terminal emulator, and start a new session.

## Contributing to ai-agent-kit from Windows

The guidance above is written for **target projects** that received a Windows
install. If you are a **contributor cloning this repository itself**, note one
extra wrinkle: the dogfood configs tracked here are the **POSIX variants**. The
tracked `.claude/settings.json` is byte-identical to `tooling/claude/settings.json`,
so its hook commands invoke bare `bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/…"`
(and `.codex/hooks.json` likewise uses `bash -c`). The Windows-safe wiring that
routes through `run-hook.ps1` lives only in `settings.windows.json` /
`hooks.windows.json` — which a PowerShell *install into a target* deploys, but
which the tracked dogfood deliberately does not use (one tracked file cannot be
both variants, and `validate --strict` accepts either).

The consequence: on a Windows checkout where `bash` resolves to the WSL launcher
stub, **this repository's own `pre-bash-guard` never runs** — the destructive-
command block is silently dead, and CI cannot detect it.

**Sanity check.** In the terminal where you launch Claude Code, confirm which
`bash` wins:

```powershell
where bash
```

If the first line is `C:\Windows\System32\bash.exe` (the WSL stub) rather than
`C:\Program Files\Git\bin\bash.exe`, your hooks are dead and you need the
override below (or fix `PATH` so Git Bash precedes `System32`).

**Override recipe.** Create `.claude/settings.local.json` at the repo root — it
is gitignored, so it never lands in a commit and never trips the dogfood drift
check. It rewires the four Claude hooks through `run-hook.ps1`, which resolves
Git Bash from `%ProgramFiles%` before falling back to `PATH`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PROJECT_DIR}/.claude/hooks/run-hook.ps1\" pre-bash-guard.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PROJECT_DIR}/.claude/hooks/run-hook.ps1\" format-on-save.sh",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PROJECT_DIR}/.claude/hooks/run-hook.ps1\" notify-done.sh",
            "async": true
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PROJECT_DIR}/.claude/hooks/run-hook.ps1\" session-summary.sh",
            "async": false
          }
        ]
      }
    ]
  }
}
```

`settings.local.json` keys are merged over `settings.json`, so only the `hooks`
block needs to be present. (This snippet mirrors the tracked
`tooling/claude/settings.windows.json` hook wiring.)

**Verify the guard is live.** After adding the override, run the hook directly
and confirm it blocks a destructive command with exit code 2:

```powershell
'{"tool_input":{"command":"git push --force"}}' |
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\.claude\hooks\run-hook.ps1" pre-bash-guard.sh
echo $LASTEXITCODE   # expect 2
```

## Troubleshooting: If Hooks Silently Do Nothing

If you suspect hooks are not executing or are silently failing:
1. Identify the project root directory (`CLAUDE_PROJECT_DIR`).
2. Run the hook script directly in test mode:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-bash-guard.sh" test 2>&1
```

3. Check the output for syntax errors, path resolution issues, or missing dependencies.
