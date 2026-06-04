# Windows Hook Setup Guidance

Claude Code hooks (such as `pre-bash-guard`, `agent-audit-event`, etc.) are shell scripts designed to run under Git Bash or WSL on Windows. Since Windows environments can resolve `bash` in different, sometimes conflicting ways, this guide outlines how to ensure hooks execute correctly.

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

In some Windows setups, `bash.exe` may resolve to the WSL wrapper executable at `%windir%\system32\bash.exe`.
- This is a valid configuration and works for running hooks.
- **Requirement:** If this path is used, you must confirm that WSL is actually installed and configured with a default Linux distribution. If WSL is not installed, this wrapper will fail or prompt to install a distro.

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

## Troubleshooting: If Hooks Silently Do Nothing

If you suspect hooks are not executing or are silently failing:
1. Identify the project root directory (`CLAUDE_PROJECT_DIR`).
2. Run the hook script directly in test mode:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-bash-guard.sh" test 2>&1
```

3. Check the output for syntax errors, path resolution issues, or missing dependencies.
