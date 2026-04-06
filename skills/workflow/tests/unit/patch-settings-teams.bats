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
  # Manually add TeammateIdle to simulate prior run
  jq '.hooks.TeammateIdle = []' .claude/settings.json > .claude/settings.json.tmp \
    && mv .claude/settings.json.tmp .claude/settings.json
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'skipped'
  assert_json_stdout_field '.reason' 'already patched'
}

@test "patch-settings-teams: adds TeammateIdle and TaskCompleted hooks" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "TeammateIdle"
  assert_file_contains "$TEST_TEMP_DIR/.claude/settings.json" "TaskCompleted"
}

@test "patch-settings-teams: creates teammate-quality-gate.sh" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh"
  assert_file_executable "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh"
}

@test "patch-settings-teams: teammate gate contains lint/test commands" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-settings-teams.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh" "npm run lint"
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/teammate-quality-gate.sh" "npm test"
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
