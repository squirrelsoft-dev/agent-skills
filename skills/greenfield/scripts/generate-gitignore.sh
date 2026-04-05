#!/bin/bash
set -e

# generate-gitignore.sh
# Appends Claude Code personal/generated file entries to .gitignore.
# Outputs JSON status to stdout. Status messages to stderr.
#
# Env vars: none

echo "Updating .gitignore..." >&2

ENTRIES=(
  "CLAUDE.local.md"
  ".claude/settings.local.json"
  ".claude/logs/"
  ".claude/scratch/"
  ".claude/tasks/"
  ".claude/specs/"
)

# Create .gitignore if it doesn't exist
touch .gitignore

# Collect entries that aren't already present
MISSING=()
for ENTRY in "${ENTRIES[@]}"; do
  if ! grep -qF "$ENTRY" .gitignore 2>/dev/null; then
    MISSING+=("$ENTRY")
  fi
done

# Add section header + missing entries
if [ "${#MISSING[@]}" -gt 0 ]; then
  if ! grep -q "Claude Code" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Claude Code — personal and generated files" >> .gitignore
  fi
  for ENTRY in "${MISSING[@]}"; do
    echo "$ENTRY" >> .gitignore
  done
fi

echo "Updated .gitignore (added ${#MISSING[@]} entries)" >&2
echo "{\"status\":\"ok\",\"entries_added\":${#MISSING[@]}}"
