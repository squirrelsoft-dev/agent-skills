#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "creates .gitignore if missing" {
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.gitignore"
}

@test "adds all 6 Claude Code entries" {
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.gitignore" 'CLAUDE.local.md'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/settings.local.json'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/logs/'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/scratch/'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/tasks/'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/specs/'
}

@test "adds section header" {
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.gitignore" '# Claude Code'
}

@test "does not duplicate entries on re-run" {
  "$SCRIPTS_DIR/generate-gitignore.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-gitignore.sh" > /dev/null 2>&1
  local count
  count=$(grep -c 'CLAUDE.local.md' "$PROJECT_DIR/.gitignore")
  [ "$count" -eq 1 ]
}

@test "does not duplicate section header on re-run" {
  "$SCRIPTS_DIR/generate-gitignore.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-gitignore.sh" > /dev/null 2>&1
  local count
  count=$(grep -c '# Claude Code' "$PROJECT_DIR/.gitignore")
  [ "$count" -eq 1 ]
}

@test "preserves existing content" {
  echo "node_modules/" > "$PROJECT_DIR/.gitignore"
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.gitignore" 'node_modules/'
  assert_file_contains "$PROJECT_DIR/.gitignore" 'CLAUDE.local.md'
}

@test "stdout returns JSON with status ok" {
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}

@test "reports entries_added count" {
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.entries_added' '6'
}

@test "reports 0 entries_added on re-run" {
  "$SCRIPTS_DIR/generate-gitignore.sh" > /dev/null 2>&1
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.entries_added' '0'
}

@test "fails without PROJECT_DIR" {
  unset PROJECT_DIR
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 1 ]
}
