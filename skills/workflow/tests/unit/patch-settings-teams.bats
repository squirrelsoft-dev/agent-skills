#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() { common_setup; }
teardown() { common_teardown; }

@test "patch-settings-teams: skips when settings.json missing" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'skipped'
  assert_json_stdout_field '.reason' 'settings.json not found'
}

@test "patch-settings-teams: skips when already patched" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  # Manually add TaskCompleted to simulate prior run
  jq '.hooks.TaskCompleted = []' .claude/settings.json > .claude/settings.json.tmp \
    && mv .claude/settings.json.tmp .claude/settings.json
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'skipped'
  assert_json_stdout_field '.reason' 'already patched'
}

@test "patch-settings-teams: adds TaskCompleted hook with format and task-summary" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "TaskCompleted"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "format.sh"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "task-summary.sh"
}

@test "patch-settings-teams: does not add TeammateIdle hook" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_file_not_contains "$TEST_TEMP_DIR/.claude/settings.json" "TeammateIdle"
}

@test "patch-settings-teams: does not create teammate-quality-gate.sh" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh" ]
}

@test "patch-settings-teams: preserves existing hooks" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "PreToolUse"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "Stop"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "SubagentStop"
}

@test "patch-settings-teams: outputs JSON with status ok" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}
