#!/bin/bash
set -e

# generate-hooks.sh
# Writes .claude/hooks/*.sh files and makes them executable.
# Outputs JSON status to stdout. Status messages to stderr.
#
# Env vars: PROJECT_DIR, LINT_CMD, TEST_CMD, FORMATTER

[[ -z "${PROJECT_DIR:-}" ]] && echo "Error: PROJECT_DIR is required" >&2 && exit 1

[[ -z "${LINT_CMD:-}" ]] && echo "Error: LINT_CMD is required" >&2 && exit 1

[[ -z "${TEST_CMD:-}" ]] && echo "Error: TEST_CMD is required" >&2 && exit 1

[[ -z "${FORMATTER:-}" ]] && echo "Error: FORMATTER is required" >&2 && exit 1

GENERATED_FILES=()
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"

echo "Generating hook scripts..." >&2

mkdir -p "$HOOKS_DIR"

# --- Resolve formatter command ---

case "$FORMATTER" in
  prettier)      FMT_CMD='npx prettier --write "$FILE" 2>/dev/null || true' ;;
  biome)         FMT_CMD='npx @biomejs/biome format --write "$FILE" 2>/dev/null || true' ;;
  ruff)          FMT_CMD='ruff format "$FILE" 2>/dev/null || true' ;;
  gofmt)         FMT_CMD='gofmt -w "$FILE" 2>/dev/null || true' ;;
  rustfmt)       FMT_CMD='rustfmt "$FILE" 2>/dev/null || true' ;;
  dotnet-format) FMT_CMD='dotnet format --include "$FILE" 2>/dev/null || true' ;;
  *)
    echo "Warning: unknown FORMATTER '$FORMATTER', format hook will be a no-op" >&2
    FMT_CMD='echo "Unknown formatter" >&2'
    ;;
esac

# --- guard.sh ---

cat > "$HOOKS_DIR/guard.sh" <<'HOOKEOF'
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
HOOKEOF
GENERATED_FILES+=(".claude/hooks/guard.sh")

# --- format.sh ---

cat > "$HOOKS_DIR/format.sh" <<'HOOKEOF'
#!/usr/bin/env bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0
HOOKEOF
echo "$FMT_CMD" >> "$HOOKS_DIR/format.sh"
GENERATED_FILES+=(".claude/hooks/format.sh")

# --- stop-quality-gate.sh ---

{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  printf 'LINT_CMD=%q\n' "$LINT_CMD"
  printf 'TEST_CMD=%q\n' "$TEST_CMD"
} > "$HOOKS_DIR/stop-quality-gate.sh"

cat >> "$HOOKS_DIR/stop-quality-gate.sh" <<'HOOKEOF'
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && echo '{"decision":"approve"}' && exit 0
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "main"')
[[ "$AGENT_TYPE" == "hook-agent" ]] && echo '{"decision":"approve"}' && exit 0
ERRORS=""
cd "$CLAUDE_PROJECT_DIR"
UNCOMMITTED=$(git diff --name-only HEAD 2>/dev/null || echo "")
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
MERGE_BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "")
if [[ -n "$MERGE_BASE" ]]; then
  COMMITTED=$(git diff --name-only "$MERGE_BASE"...HEAD 2>/dev/null || echo "")
else
  COMMITTED=""
fi
CHANGED="${UNCOMMITTED}${UNTRACKED}${COMMITTED}"
[[ -z "$CHANGED" ]] && echo '{"decision":"approve"}' && exit 0
# Security — secret detection
if command -v gitleaks &>/dev/null; then
  if output=$(gitleaks detect --no-git --source=. --verbose 2>&1 | grep -E "Secret|Finding|leak"); then
    [[ -n "$output" ]] && ERRORS+="\n## Secrets Detected (gitleaks)\n\`\`\`\n${output}\n\`\`\`\n"
  fi
else
  echo "gitleaks not installed — skipping secret detection" >&2
fi
# Security — SAST
if command -v semgrep &>/dev/null; then
  if output=$(semgrep --config=auto --quiet 2>/dev/null | grep -v "^$"); then
    [[ -n "$output" ]] && ERRORS+="\n## Security Issues (semgrep)\n\`\`\`\n${output}\n\`\`\`\n"
  fi
else
  echo "semgrep not installed — skipping SAST scan" >&2
fi
# Lint
if ! output=$(eval "$LINT_CMD" 2>&1); then
  ERRORS+="\n## Lint Failed\n\`\`\`\n${output}\n\`\`\`\n"
fi
if ! output=$(eval "$TEST_CMD" 2>&1); then
  ERRORS+="\n## Tests Failed\n\`\`\`\n${output}\n\`\`\`\n"
fi
if [[ -n "$ERRORS" ]]; then
  REASON=$(printf '%b' "$ERRORS" | jq -Rs .)
  echo "{\"decision\":\"block\",\"reason\":$REASON}"
  exit 0
fi
echo '{"decision":"approve"}'
exit 0
HOOKEOF
GENERATED_FILES+=(".claude/hooks/stop-quality-gate.sh")

# --- task-summary.sh ---

cat > "$HOOKS_DIR/task-summary.sh" <<'HOOKEOF'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
{
  echo "# Session Complete — $TIMESTAMP"
  echo "Branch: $BRANCH"
  echo ""
  echo "## Files Changed"
  git diff --stat HEAD 2>/dev/null || git status --short
  echo ""
  echo "## Recent Commits"
  git log --oneline -5 2>/dev/null || echo "(no commits)"
} > "$CLAUDE_PROJECT_DIR/.claude/logs/session-$TIMESTAMP.md" 2>/dev/null
exit 0
HOOKEOF
GENERATED_FILES+=(".claude/hooks/task-summary.sh")

# --- save-context.sh ---

cat > "$HOOKS_DIR/save-context.sh" <<'HOOKEOF'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/scratch"
SCRATCH="$CLAUDE_PROJECT_DIR/.claude/scratch/wip-$(date +%Y%m%d-%H%M%S).md"
INPUT=$(cat)
CUSTOM=$(echo "$INPUT" | jq -r '.custom_instructions // empty')
cat > "$SCRATCH" <<EOF
# WIP Snapshot — $(date)
${CUSTOM}
## Git Status
$(cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "unavailable")
EOF
echo "Context saved to $SCRATCH" >&2
exit 0
HOOKEOF
GENERATED_FILES+=(".claude/hooks/save-context.sh")

# --- session-start.sh ---

cat > "$HOOKS_DIR/session-start.sh" <<'HOOKEOF'
#!/usr/bin/env bash
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
if [[ "$AGENT_TYPE" == "subagent" ]] || [[ "$AGENT_TYPE" == "teammate" ]]; then
  exit 0
fi
echo "## Git State"
cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "(not a git repo)"
echo ""
echo "## Branch"
git branch --show-current 2>/dev/null || echo "(unknown)"
echo ""
echo "## Recent Commits"
git log --oneline -5 2>/dev/null || echo "(no commits yet)"
exit 0
HOOKEOF
GENERATED_FILES+=(".claude/hooks/session-start.sh")

# --- Finalize ---

chmod +x "$HOOKS_DIR"/*.sh

echo "Wrote ${#GENERATED_FILES[@]} hook scripts" >&2

printf -v FILES_JSON '"%s",' "${GENERATED_FILES[@]}"
printf '{"status":"ok","files":[%s]}\n' "${FILES_JSON%,}"
