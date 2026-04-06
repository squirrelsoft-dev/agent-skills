#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() { common_setup; }
teardown() { common_teardown; }

@test "install-commands: creates .claude/commands/ directory" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents COMMANDS=commit run "$SCRIPTS_DIR/install-commands.sh"
  [ "$status" -eq 0 ]
  assert_dir_exists "$TEST_TEMP_DIR/.claude/commands"
}

@test "install-commands: subagents mode installs subagents variant" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents COMMANDS=breakdown run "$SCRIPTS_DIR/install-commands.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/commands/breakdown.md" "dependency tracking"
}

@test "install-commands: teams mode installs teams variant" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=teams COMMANDS=breakdown run "$SCRIPTS_DIR/install-commands.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/commands/breakdown.md" "domain ownership"
}

@test "install-commands: default COMMANDS installs all expected files" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents run "$SCRIPTS_DIR/install-commands.sh"
  [ "$status" -eq 0 ]
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
}

@test "install-commands: respects COMMANDS subset" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents COMMANDS=commit,review run "$SCRIPTS_DIR/install-commands.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/commit.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/commands/review.md"
  [ ! -f "$TEST_TEMP_DIR/.claude/commands/breakdown.md" ]
  [ ! -f "$TEST_TEMP_DIR/.claude/commands/pr.md" ]
}

@test "install-commands: outputs JSON with status ok" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents COMMANDS=commit run "$SCRIPTS_DIR/install-commands.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}
