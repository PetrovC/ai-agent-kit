#!/usr/bin/env bash
# notify-done.sh — Stop hook
#
# Sends a desktop notification when Claude finishes a turn.
# Runs async so it never blocks the response.
#
# SETUP in .claude/settings.json:
#   "hooks": {
#     "Stop": [{
#       "matcher": "",
#       "hooks": [{"type": "command", "command": ".claude/hooks/notify-done.sh", "async": true}]
#     }]
#   }
set -euo pipefail

# MSG/TITLE are hardcoded today, but the macOS and Windows branches build a
# script string in *another language* (AppleScript / PowerShell). If a future
# change ever wires turn/file data into MSG, plain string interpolation would
# let an attacker break out of the quoting and execute arbitrary code under
# the user's account. The script is now structured so MSG is ONLY passed via
# the process environment — never interpolated into a command-string source —
# and each backend reads it from there. Stays safe even if MSG becomes dynamic.
export MSG="Claude finished"
export TITLE="Claude Code"

# macOS — terminal-notifier (MSG is its own argv element, already safe)
if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "$TITLE" -message "$MSG" -sound default || true
    exit 0
fi

# macOS — osascript: AppleScript reads MSG via `system attribute`, so the
# script source itself contains no expansion of MSG. The -e argument is
# single-quoted on the bash side, so no shell interpolation either.
if command -v osascript &>/dev/null; then
    osascript -e 'display notification (system attribute "MSG") with title (system attribute "TITLE")' 2>/dev/null || true
    exit 0
fi

# Linux (libnotify) — argv elements, already safe.
if command -v notify-send &>/dev/null; then
    notify-send "$TITLE" "$MSG" || true
    exit 0
fi

# Windows (PowerShell toast). PowerShell reads MSG/TITLE from $env:* — the
# -Command argument is single-quoted on the bash side, so MSG is never
# interpolated into the PowerShell source.
if command -v powershell.exe &>/dev/null; then
    powershell.exe -NonInteractive -Command \
        '[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
         $t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01);
         $t.GetElementsByTagName("text")[0].AppendChild($t.CreateTextNode($env:MSG)) | Out-Null;
         [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($env:TITLE).Show([Windows.UI.Notifications.ToastNotification]::new($t))' \
        2>/dev/null || true
fi

exit 0
