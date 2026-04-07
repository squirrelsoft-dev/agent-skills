#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() {
  SKILL_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
}

@test "package: SKILL.md exists" {
  assert_file_exists "$SKILL_DIR/SKILL.md"
}

@test "package: SKILL.md is under 500 lines" {
  local lines
  lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -lt 500 ]
}

@test "package: all 6 scripts exist" {
  assert_file_exists "$SKILL_DIR/scripts/detect-tools.sh"
  assert_file_exists "$SKILL_DIR/scripts/install-commands.sh"
  assert_file_exists "$SKILL_DIR/scripts/install-agents.sh"
  assert_file_exists "$SKILL_DIR/scripts/install-triage-skill.sh"
  assert_file_exists "$SKILL_DIR/scripts/patch-quality-gate.sh"
  assert_file_exists "$SKILL_DIR/scripts/patch-settings-teams.sh"
}

@test "package: all scripts are executable" {
  assert_file_executable "$SKILL_DIR/scripts/detect-tools.sh"
  assert_file_executable "$SKILL_DIR/scripts/install-commands.sh"
  assert_file_executable "$SKILL_DIR/scripts/install-agents.sh"
  assert_file_executable "$SKILL_DIR/scripts/install-triage-skill.sh"
  assert_file_executable "$SKILL_DIR/scripts/patch-quality-gate.sh"
  assert_file_executable "$SKILL_DIR/scripts/patch-settings-teams.sh"
}

@test "package: all 14 command references exist" {
  assert_file_exists "$SKILL_DIR/references/commands/breakdown-subagents.md"
  assert_file_exists "$SKILL_DIR/references/commands/breakdown-teams.md"
  assert_file_exists "$SKILL_DIR/references/commands/spec-subagents.md"
  assert_file_exists "$SKILL_DIR/references/commands/spec-teams.md"
  assert_file_exists "$SKILL_DIR/references/commands/work-subagents.md"
  assert_file_exists "$SKILL_DIR/references/commands/work-teams.md"
  assert_file_exists "$SKILL_DIR/references/commands/commit.md"
  assert_file_exists "$SKILL_DIR/references/commands/fix-issue.md"
  assert_file_exists "$SKILL_DIR/references/commands/pr.md"
  assert_file_exists "$SKILL_DIR/references/commands/review.md"
  assert_file_exists "$SKILL_DIR/references/commands/security-scan.md"
  assert_file_exists "$SKILL_DIR/references/commands/squash-pr.md"
  assert_file_exists "$SKILL_DIR/references/commands/address-pr-comments.md"
  assert_file_exists "$SKILL_DIR/references/commands/update-skills.md"
}

@test "package: all 5 agent references exist" {
  assert_file_exists "$SKILL_DIR/references/agents/architect.md"
  assert_file_exists "$SKILL_DIR/references/agents/implementer.md"
  assert_file_exists "$SKILL_DIR/references/agents/domain-implementer.md"
  assert_file_exists "$SKILL_DIR/references/agents/quality.md"
  assert_file_exists "$SKILL_DIR/references/agents/git-expert.md"
}

@test "package: triage-skill.md reference exists" {
  assert_file_exists "$SKILL_DIR/references/triage-skill.md"
}

@test "package: total file count is 29" {
  local count
  count=$(find "$SKILL_DIR" -type f -not -path "*/tests/*" 2>/dev/null | wc -l)
  [ "$count" -eq 29 ]
}
