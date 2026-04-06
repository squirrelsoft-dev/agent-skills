#!/bin/bash
set -e
# generate-hooks.sh
# Writes .claude/hooks/ scripts tailored to detected tools.
# Commands come from analysis JSON — not hardcoded defaults.

echo "Generating hook scripts..." >&2

mkdir -p .claude/hooks

LINT_CMD="${LINT_CMD:-echo 'no lint configured'}"
TEST_CMD="${TEST_CMD:-echo 'no test configured'}"
FORMATTER="${FORMATTER:-prettier}"
AGENT_TEAMS="${AGENT_TEAMS:-false}"

# --- guard.sh ---
cat > .claude/hooks/guard.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && echo '{"decision":"approve"}' && exit 0
if echo "$CMD" | grep -qEi '(rm -rf /|DROP TABLE|DROP DATABASE|DELETE FROM .* WHERE 1=1|push\s+.*--force|> /dev/sd|mkfs|dd if=)'; then
  echo '{"decision":"block","reason":"Blocked: destructive command detected."}'
  exit 0
fi
if echo "$CMD" | grep -qEi '(curl.*(-d|--data).*(_KEY|_SECRET|_TOKEN|PASSWORD)|echo.*(_KEY|_SECRET|_TOKEN))'; then
  echo '{"decision":"block","reason":"Blocked: potential secret exposure. Use environment variables."}'
  exit 0
fi
echo '{"decision":"approve"}'
HOOK

# --- format.sh (formatter-specific) ---
cat > .claude/hooks/format.sh <<HOOK
#!/usr/bin/env bash
INPUT=\$(cat)
FILE=\$(echo "\$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "\$FILE" ]] && exit 0
[[ ! -f "\$FILE" ]] && exit 0
HOOK

case "$FORMATTER" in
  biome)   echo 'npx @biomejs/biome format --write "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  ruff)    echo 'ruff format "$FILE" 2>/dev/null || black "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  gofmt)   echo 'gofmt -w "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  rustfmt) echo 'rustfmt "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  *)       echo 'npx prettier --write "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
esac

# --- stop-quality-gate.sh (uses actual detected commands) ---
cat > .claude/hooks/stop-quality-gate.sh <<HOOK
#!/usr/bin/env bash
set -euo pipefail
INPUT=\$(cat)
STOP_HOOK_ACTIVE=\$(echo "\$INPUT" | jq -r '.stop_hook_active // false')
[[ "\$STOP_HOOK_ACTIVE" == "true" ]] && exit 0
AGENT_TYPE=\$(echo "\$INPUT" | jq -r '.agent_type // "main"')
[[ "\$AGENT_TYPE" == "hook-agent" ]] && exit 0
ERRORS=""
cd "\$CLAUDE_PROJECT_DIR"
CHANGED=\$(git diff --name-only HEAD 2>/dev/null || echo "")
[[ -z "\$CHANGED" ]] && exit 0
# Lint
if ! output=\$(${LINT_CMD} 2>&1); then
  ERRORS+="\n## Lint Failed\n\`\`\`\n\${output}\n\`\`\`\n"
fi
if ! output=\$(${TEST_CMD} 2>&1); then
  ERRORS+="\n## Tests Failed\n\`\`\`\n\${output}\n\`\`\`\n"
fi
if [[ -n "\$ERRORS" ]]; then
  printf "Quality gate failed — fix before completing:\n%b" "\$ERRORS" >&2
  exit 2
fi
exit 0
HOOK

# --- teammate-quality-gate.sh (only if agent teams enabled) ---
if [ "$AGENT_TEAMS" = "true" ]; then
cat > .claude/hooks/teammate-quality-gate.sh <<HOOK
#!/usr/bin/env bash
set -euo pipefail
INPUT=\$(cat)
TEAMMATE=\$(echo "\$INPUT" | jq -r '.teammate_name // "teammate"')
TASK=\$(echo "\$INPUT" | jq -r '.task_subject // "current task"')
ERRORS=""
cd "\$CLAUDE_PROJECT_DIR"
CHANGED=\$(git diff --name-only HEAD 2>/dev/null || echo "")
[[ -z "\$CHANGED" ]] && exit 0
if ! output=\$(${LINT_CMD} 2>&1); then
  ERRORS+="\n## Lint Failed\n\`\`\`\n\${output}\n\`\`\`\n"
fi
if ! output=\$(${TEST_CMD} 2>&1); then
  ERRORS+="\n## Tests Failed\n\`\`\`\n\${output}\n\`\`\`\n"
fi
if [[ -n "\$ERRORS" ]]; then
  printf "%s: fix before marking '%s' done:\n%b" "\$TEAMMATE" "\$TASK" "\$ERRORS" >&2
  exit 2
fi
exit 0
HOOK
fi

# --- task-summary.sh ---
cat > .claude/hooks/task-summary.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
{
  echo "# Session — $TIMESTAMP | Branch: $BRANCH"
  echo ""
  git diff --stat HEAD 2>/dev/null || git status --short
  echo ""
  git log --oneline -5 2>/dev/null
} > "$CLAUDE_PROJECT_DIR/.claude/logs/session-$TIMESTAMP.md" 2>/dev/null
exit 0
HOOK

# --- save-context.sh ---
cat > .claude/hooks/save-context.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/scratch"
SCRATCH="$CLAUDE_PROJECT_DIR/.claude/scratch/wip-$(date +%Y%m%d-%H%M%S).md"
INPUT=$(cat)
CUSTOM=$(echo "$INPUT" | jq -r '.custom_instructions // empty')
{ echo "# WIP — $(date)"; echo "$CUSTOM"; echo ""; git status --short 2>/dev/null; } > "$SCRATCH"
echo "Context saved to $SCRATCH" >&2
exit 0
HOOK

# --- session-start.sh ---
cat > .claude/hooks/session-start.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
[[ "$AGENT_TYPE" == "subagent" || "$AGENT_TYPE" == "teammate" ]] && exit 0
echo "## Git State"
cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "(not a git repo)"
echo ""
echo "## Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
echo ""
echo "## Recent Commits"
git log --oneline -5 2>/dev/null || echo "(no commits)"
exit 0
HOOK

chmod +x .claude/hooks/*.sh

echo "Hook scripts written and made executable" >&2
HOOKS="guard.sh format.sh stop-quality-gate.sh task-summary.sh save-context.sh session-start.sh"
[ "$AGENT_TEAMS" = "true" ] && HOOKS="$HOOKS teammate-quality-gate.sh"
echo "{\"status\":\"ok\",\"files\":\"$HOOKS\"}"
