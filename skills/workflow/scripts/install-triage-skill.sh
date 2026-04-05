#!/bin/bash
set -e
# install-triage-skill.sh
# Installs the triage skill to .claude/skills/triage/
# Requires gh CLI to be installed.

echo "Installing triage skill..." >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p .claude/skills/triage

cp "$SCRIPT_DIR/../references/triage-skill.md" .claude/skills/triage/SKILL.md

echo "Triage skill installed at .claude/skills/triage/SKILL.md" >&2
echo '{"status":"ok","path":".claude/skills/triage/SKILL.md"}'
