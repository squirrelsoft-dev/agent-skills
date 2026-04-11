#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"

  export ORCHESTRATION="subagents"
  export COMMANDS="breakdown,commit,review,pr,fix-issue,security-scan,triage,update-skills"
  export STACK="nextjs"

  # Detect tools
  local detect_out
  detect_out=$("$SCRIPTS_DIR/detect-tools.sh" 2>/dev/null)
  export GITLEAKS=$(echo "$detect_out" | jq -r '.gitleaks')
  export SEMGREP=$(echo "$detect_out" | jq -r '.semgrep')

  # Run install scripts
  "$SCRIPTS_DIR/install-commands.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/install-agents.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/install-triage-skill.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/patch-quality-gate.sh" > /dev/null 2>&1
}

teardown() { common_teardown; }

@test "e2e/subagents: all 11 commands installed" {
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/breakdown.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/spec.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/work.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/commit.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/review.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/pr.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/squash-pr.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/address-pr-comments.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/fix-issue.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/security-scan.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/update-skills.md"
}

@test "e2e/subagents: breakdown is subagents variant" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/commands/breakdown.md" "dependency tracking"
}

@test "e2e/subagents: 5 agents installed correctly" {
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/architect.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/quality.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/git-expert.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/manager.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/implementer.md"
  [ ! -f "$TEST_TEMP_DIR/.claude/agents/domain-implementer.md" ]
}

@test "e2e/subagents: triage skill installed" {
  assert_file_exists "$TEST_TEMP_DIR/.claude/skills/triage/SKILL.md"
}

@test "e2e/subagents: no teams hooks in settings.json" {
  assert_file_not_contains "$TEST_TEMP_DIR/.claude/settings.json" "TeammateIdle"
  assert_file_not_contains "$TEST_TEMP_DIR/.claude/settings.json" "TaskCompleted"
}

@test "e2e/subagents: no teammate-quality-gate.sh" {
  [ ! -f "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh" ]
}

@test "e2e/subagents: original greenfield hooks preserved" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "PreToolUse"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "Stop"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "SessionStart"
}
