#!/usr/bin/env bash
# notify-done.sh — Codex Stop hook
#
# Sends a desktop notification when Codex finishes a turn. Best-effort.
#
# Wired in .codex/hooks.json:
#   { "hooks": { "Stop": [
#       { "matcher": "",
#         "hooks": [{"type":"command","command":".codex/hooks/notify-done.sh"}] } ] } }
set -euo pipefail

MSG="Codex finished"

# macOS
if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "Codex CLI" -message "$MSG" -sound default
    exit 0
fi
if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MSG\" with title \"Codex CLI\""
    exit 0
fi

# Linux (libnotify)
if command -v notify-send &>/dev/null; then
    notify-send "Codex CLI" "$MSG"
    exit 0
fi

# Windows (PowerShell toast) — only works when shell is PowerShell
if command -v powershell.exe &>/dev/null; then
    powershell.exe -NonInteractive -Command \
        "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null; \$t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01); \$t.GetElementsByTagName('text')[0].AppendChild(\$t.CreateTextNode('$MSG')) | Out-Null; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Codex CLI').Show([Windows.UI.Notifications.ToastNotification]::new(\$t))" \
        2>/dev/null || true
fi

exit 0
