#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"

  export ORCHESTRATION="teams"
  export COMMANDS="breakdown,commit,review,pr,fix-issue,security-scan,triage,update-skills"
  export STACK="nextjs"

  # Detect tools
  local detect_out
  detect_out=$("$SCRIPTS_DIR/detect-tools.sh" 2>/dev/null)
  export GITLEAKS=$(echo "$detect_out" | jq -r '.gitleaks')
  export SEMGREP=$(echo "$detect_out" | jq -r '.semgrep')

  # Run all install scripts — patch-settings-teams before patch-quality-gate
  # so that lint/test command extraction reads the un-patched gate file
  "$SCRIPTS_DIR/install-commands.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/install-agents.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/install-triage-skill.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/patch-settings-teams.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/patch-quality-gate.sh" > /dev/null 2>&1
}

teardown() { common_teardown; }

@test "e2e/teams: all 11 commands installed" {
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

@test "e2e/teams: breakdown is teams variant" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/commands/breakdown.md" "domain ownership"
}

@test "e2e/teams: 4 agents installed correctly" {
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/architect.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/quality.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/git-expert.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/domain-implementer.md"
  [ ! -f "$TEST_TEMP_DIR/.claude/agents/implementer.md" ]
}

@test "e2e/teams: triage skill installed" {
  assert_file_exists "$TEST_TEMP_DIR/.claude/skills/triage/SKILL.md"
}

@test "e2e/teams: TeammateIdle hook in settings.json" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "TeammateIdle"
}

@test "e2e/teams: TaskCompleted hook in settings.json" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "TaskCompleted"
}

@test "e2e/teams: teammate-quality-gate.sh exists and is executable" {
  assert_file_exists "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh"
  assert_file_executable "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh"
}

@test "e2e/teams: teammate gate has lint/test commands from fixture" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh" "npm run lint"
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh" "npm test"
}

@test "e2e/teams: original greenfield hooks preserved" {
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "PreToolUse"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "Stop"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "SessionStart"
}
