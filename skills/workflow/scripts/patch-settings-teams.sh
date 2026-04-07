#!/bin/bash
set -e
# patch-settings-teams.sh
# Configures agent teams hooks in .claude/settings.json
# TaskCompleted runs format + task-summary (quality gates are handled by the Quality Gate agent)

SETTINGS=".claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "settings.json not found — skipping" >&2
  echo '{"status":"skipped","reason":"settings.json not found"}'
  exit 0
fi

if grep -q "TaskCompleted" "$SETTINGS"; then
  echo "Already patched — skipping" >&2
  echo '{"status":"skipped","reason":"already patched"}'
  exit 0
fi

echo "Patching settings.json for agent teams..." >&2

if command -v jq &>/dev/null; then
  jq --arg fmt 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/format.sh"' \
     --arg sum 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/task-summary.sh"' '
    .hooks.TaskCompleted = [{"hooks": [
      {"type": "command", "command": $fmt},
      {"type": "command", "command": $sum}
    ]}]
  ' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  echo "settings.json patched" >&2
else
  echo "WARNING: jq not found. Manually add TaskCompleted to .claude/settings.json" >&2
fi

echo '{"status":"ok"}'
