#!/bin/bash
set -e

# generate-gitignore.sh
# Appends Claude Code personal/generated file entries to .gitignore.
# Outputs JSON status to stdout. Status messages to stderr.
#
# Env vars: PROJECT_DIR

[[ -z "${PROJECT_DIR:-}" ]] && echo "Error: PROJECT_DIR is required" >&2 && exit 1

GITIGNORE="$PROJECT_DIR/.gitignore"

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
mkdir -p "$PROJECT_DIR"
touch "$GITIGNORE"

# Collect entries that aren't already present
MISSING=()
for ENTRY in "${ENTRIES[@]}"; do
  if ! grep -qxF "$ENTRY" "$GITIGNORE" 2>/dev/null; then
    MISSING+=("$ENTRY")
  fi
done

# Add section header + missing entries
if [ "${#MISSING[@]}" -gt 0 ]; then
  if ! grep -qF "# Claude Code" "$GITIGNORE" 2>/dev/null; then
    if [ -s "$GITIGNORE" ]; then
      echo "" >> "$GITIGNORE"
    fi
    echo "# Claude Code — personal and generated files" >> "$GITIGNORE"
  fi
  for ENTRY in "${MISSING[@]}"; do
    echo "$ENTRY" >> "$GITIGNORE"
  done
fi

echo "Updated .gitignore (added ${#MISSING[@]} entries)" >&2
echo "{\"status\":\"ok\",\"entries_added\":${#MISSING[@]}}"
