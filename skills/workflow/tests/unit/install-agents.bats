#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() { common_setup; }
teardown() { common_teardown; }

@test "install-agents: creates .claude/agents/ directory" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents run "$SCRIPTS_DIR/install-agents.sh"
  [ "$status" -eq 0 ]
  assert_dir_exists "$TEST_TEMP_DIR/.claude/agents"
}

@test "install-agents: always installs architect, quality, git-expert" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents run "$SCRIPTS_DIR/install-agents.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/architect.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/quality.md"
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/git-expert.md"
}

@test "install-agents: subagents mode installs implementer.md" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents run "$SCRIPTS_DIR/install-agents.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/implementer.md"
  [ ! -f "$TEST_TEMP_DIR/.claude/agents/domain-implementer.md" ]
}

@test "install-agents: teams mode installs domain-implementer.md" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=teams run "$SCRIPTS_DIR/install-agents.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_TEMP_DIR/.claude/agents/domain-implementer.md"
  [ ! -f "$TEST_TEMP_DIR/.claude/agents/implementer.md" ]
}

@test "install-agents: outputs JSON with status ok" {
  cd "$TEST_TEMP_DIR"
  ORCHESTRATION=subagents run "$SCRIPTS_DIR/install-agents.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}
