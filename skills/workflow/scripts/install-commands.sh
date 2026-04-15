#!/bin/bash
set -e
# install-commands.sh
# Copies command reference files to .claude/commands/
# ORCHESTRATION: "subagents" or "teams"
# COMMANDS: comma-separated list of approved command groups

echo "Installing slash commands..." >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$SCRIPT_DIR/../references/commands"
mkdir -p .claude/commands

ORCHESTRATION="${ORCHESTRATION:-subagents}"
COMMANDS="${COMMANDS:-breakdown,commit,review,pr,fix-issue,security-scan,triage,update-skills}"

# breakdown / spec / work — install mode-specific version
if echo "$COMMANDS" | grep -q "breakdown"; then
  if [ "$ORCHESTRATION" = "teams" ]; then
    cp "$REFS/breakdown-teams.md" .claude/commands/breakdown.md
    cp "$REFS/spec-teams.md"      .claude/commands/spec.md
    cp "$REFS/work-teams.md"      .claude/commands/work.md
    echo "Installed breakdown/spec/work (agent teams mode)" >&2
  elif [ "$ORCHESTRATION" = "loop" ]; then
    cp "$REFS/breakdown-subagents.md" .claude/commands/breakdown.md
    cp "$REFS/spec-subagents.md"      .claude/commands/spec.md
    cp "$REFS/work-loop.md"           .claude/commands/work.md
    echo "Installed breakdown/spec/work (PEE loop mode)" >&2
  else
    cp "$REFS/breakdown-subagents.md" .claude/commands/breakdown.md
    cp "$REFS/spec-subagents.md"      .claude/commands/spec.md
    cp "$REFS/work-subagents.md"      .claude/commands/work.md
    echo "Installed breakdown/spec/work (subagents mode)" >&2
  fi
fi

echo "$COMMANDS" | grep -q "commit"    && cp "$REFS/commit.md"              .claude/commands/commit.md
echo "$COMMANDS" | grep -q "review"    && cp "$REFS/review.md"              .claude/commands/review.md
echo "$COMMANDS" | grep -q "pr"        && cp "$REFS/pr.md"                  .claude/commands/pr.md
echo "$COMMANDS" | grep -q "pr"        && cp "$REFS/squash-pr.md"           .claude/commands/squash-pr.md
echo "$COMMANDS" | grep -q "pr"        && cp "$REFS/address-pr-comments.md" .claude/commands/address-pr-comments.md
echo "$COMMANDS" | grep -q "fix-issue" && cp "$REFS/fix-issue.md"           .claude/commands/fix-issue.md
echo "$COMMANDS" | grep -q "security"       && cp "$REFS/security-scan.md"       .claude/commands/security-scan.md
echo "$COMMANDS" | grep -q "update-skills"  && cp "$REFS/update-skills.md"      .claude/commands/update-skills.md

INSTALLED=$(ls .claude/commands/ | tr '\n' ' ')
echo "Commands installed: $INSTALLED" >&2
echo "{\"status\":\"ok\",\"installed\":\"$INSTALLED\"}"
