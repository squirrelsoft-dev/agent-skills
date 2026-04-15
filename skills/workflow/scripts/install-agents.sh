#!/bin/bash
set -e
# install-agents.sh
# Copies agent definition files to .claude/agents/
# ORCHESTRATION: "subagents" or "teams"

echo "Installing agents..." >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$SCRIPT_DIR/../references/agents"
mkdir -p .claude/agents

ORCHESTRATION="${ORCHESTRATION:-subagents}"

# architect, quality, git-expert, and manager always installed
cp "$REFS/architect.md"  .claude/agents/architect.md
cp "$REFS/quality.md"    .claude/agents/quality.md
cp "$REFS/git-expert.md" .claude/agents/git-expert.md
cp "$REFS/manager.md"    .claude/agents/manager.md

# implementer variant depends on mode
if [ "$ORCHESTRATION" = "teams" ]; then
  cp "$REFS/domain-implementer.md" .claude/agents/domain-implementer.md
  echo "Installed domain-implementer (agent teams mode)" >&2
elif [ "$ORCHESTRATION" = "loop" ]; then
  cp "$REFS/planner.md"   .claude/agents/planner.md
  cp "$REFS/executor.md"  .claude/agents/executor.md
  cp "$REFS/evaluator.md" .claude/agents/evaluator.md
  echo "Installed planner/executor/evaluator (PEE loop mode)" >&2
else
  cp "$REFS/implementer.md" .claude/agents/implementer.md
  echo "Installed implementer (subagents mode)" >&2
fi

INSTALLED=$(ls .claude/agents/ | tr '\n' ' ')
echo "Agents installed: $INSTALLED" >&2
echo "{\"status\":\"ok\",\"installed\":\"$INSTALLED\"}"
