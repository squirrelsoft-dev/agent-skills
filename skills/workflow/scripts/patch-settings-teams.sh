#!/bin/bash
set -e
# patch-settings-teams.sh
# Adds agent teams hooks to .claude/settings.json
# Creates .claude/hooks/teammate-quality-gate.sh

SETTINGS=".claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "settings.json not found — skipping" >&2
  echo '{"status":"skipped","reason":"settings.json not found"}'
  exit 0
fi

if grep -q "TeammateIdle" "$SETTINGS"; then
  echo "Already patched — skipping" >&2
  echo '{"status":"skipped","reason":"already patched"}'
  exit 0
fi

echo "Patching settings.json for agent teams..." >&2

# Extract lint/test commands from existing stop-quality-gate.sh
LINT_CMD=$(grep -m1 'output=$(' .claude/hooks/stop-quality-gate.sh 2>/dev/null \
  | sed 's/.*output=\$(//;s/ 2>&1.*//' || echo "npm run lint")
TEST_CMD=$(grep -m2 'output=$(' .claude/hooks/stop-quality-gate.sh 2>/dev/null \
  | tail -1 | sed 's/.*output=\$(//;s/ 2>&1.*//' || echo "npm test")

if command -v jq &>/dev/null; then
  HOOK_CMD='bash "$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-quality-gate.sh"'
  jq --arg cmd "$HOOK_CMD" '
    .hooks.TeammateIdle = [{"hooks": [{"type": "command", "command": $cmd}]}] |
    .hooks.TaskCompleted = [{"hooks": [{"type": "command", "command": $cmd}]}]
  ' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  echo "settings.json patched" >&2
else
  echo "WARNING: jq not found. Manually add TeammateIdle and TaskCompleted to .claude/settings.json" >&2
fi

# Create teammate-quality-gate.sh using detected commands
LINT="${LINT_CMD:-npm run lint}"
TEST="${TEST_CMD:-npm test}"

cat > .claude/hooks/teammate-quality-gate.sh << HOOKEOF
#!/usr/bin/env bash
# TeammateIdle/TaskCompleted — gates teammates until quality passes
# Exit 2 sends feedback back to THIS teammate, not the lead agent.
set -euo pipefail
INPUT=\$(cat)
TEAMMATE=\$(echo "\$INPUT" | jq -r '.teammate_name // "teammate"')
TASK=\$(echo "\$INPUT" | jq -r '.task_subject // "current task"')
ERRORS=""
cd "\$CLAUDE_PROJECT_DIR"
CHANGED=\$(git diff --name-only HEAD 2>/dev/null || echo "")
[[ -z "\$CHANGED" ]] && exit 0
if ! output=\$(${LINT} 2>&1); then
  ERRORS+="\\n## Lint Failed\\n\\\`\\\`\\\`\\n\${output}\\n\\\`\\\`\\\`\\n"
fi
if ! output=\$(${TEST} 2>&1); then
  ERRORS+="\\n## Tests Failed\\n\\\`\\\`\\\`\\n\${output}\\n\\\`\\\`\\\`\\n"
fi
if [[ -n "\$ERRORS" ]]; then
  printf "%s: fix before marking '%s' done:\\n%b" "\$TEAMMATE" "\$TASK" "\$ERRORS" >&2
  exit 2
fi
exit 0
HOOKEOF

chmod +x .claude/hooks/teammate-quality-gate.sh
echo "teammate-quality-gate.sh created" >&2
echo '{"status":"ok"}'
