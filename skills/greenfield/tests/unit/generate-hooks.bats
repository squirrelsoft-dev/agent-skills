#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  export LINT_CMD="npm run lint"
  export TEST_CMD="npm test"
  export FORMATTER="prettier"
}

teardown() {
  common_teardown
}

@test "creates all 6 hook scripts" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/hooks/guard.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/format.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/task-summary.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/save-context.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/session-start.sh"
}

@test "all hooks are executable" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_executable "$PROJECT_DIR/.claude/hooks/guard.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/format.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/task-summary.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/save-context.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/session-start.sh"
}

@test "format.sh uses prettier command" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'npx prettier --write'
}

@test "format.sh uses ruff command" {
  export FORMATTER="ruff"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'ruff format'
}

@test "format.sh uses biome command" {
  export FORMATTER="biome"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'biomejs/biome format'
}

@test "format.sh falls back to no-op for unknown formatter" {
  export FORMATTER="unknown"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'Unknown formatter'
}

@test "stop-quality-gate.sh embeds LINT_CMD" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  # printf %q shell-quotes spaces, so "npm run lint" becomes "npm\ run\ lint"
  assert_file_matches "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'LINT_CMD=.*npm.*lint'
}

@test "stop-quality-gate.sh embeds TEST_CMD" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_matches "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'TEST_CMD=.*npm.*test'
}

@test "guard.sh blocks destructive rm -rf" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  result=$(echo '{"tool_input":{"command":"rm -rf /"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"block"'
}

@test "guard.sh blocks DROP TABLE" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  result=$(echo '{"tool_input":{"command":"psql -c DROP TABLE users"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"block"'
}

@test "guard.sh approves safe commands" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  result=$(echo '{"tool_input":{"command":"ls -la"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"approve"'
}

@test "guard.sh approves when no command present" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  result=$(echo '{"tool_input":{}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"approve"'
}

@test "stdout returns JSON with status ok" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}

@test "stdout reports 6 files" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_count '.files | length' '6'
}

@test "fails without PROJECT_DIR" {
  unset PROJECT_DIR
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}

@test "fails without LINT_CMD" {
  unset LINT_CMD
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}

@test "fails without TEST_CMD" {
  unset TEST_CMD
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}

@test "fails without FORMATTER" {
  unset FORMATTER
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}
