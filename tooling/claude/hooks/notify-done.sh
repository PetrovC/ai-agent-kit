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

MSG="Claude finished"

# macOS
if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "Claude Code" -message "$MSG" -sound default
    exit 0
fi
if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MSG\" with title \"Claude Code\""
    exit 0
fi

# Linux (libnotify)
if command -v notify-send &>/dev/null; then
    notify-send "Claude Code" "$MSG"
    exit 0
fi

# Windows (PowerShell toast) — only works when shell is PowerShell
if command -v powershell.exe &>/dev/null; then
    powershell.exe -NonInteractive -Command \
        "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null; \$t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01); \$t.GetElementsByTagName('text')[0].AppendChild(\$t.CreateTextNode('$MSG')) | Out-Null; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new(\$t))" \
        2>/dev/null || true
fi

exit 0
