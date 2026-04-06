#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() { common_setup; }
teardown() { common_teardown; }

@test "install-triage-skill: creates .claude/skills/triage/SKILL.md" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/install-triage-skill.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_TEMP_DIR/.claude/skills/triage/SKILL.md"
}

@test "install-triage-skill: content matches reference" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/install-triage-skill.sh"
  [ "$status" -eq 0 ]
  local ref_file
  ref_file="$(cd "$SCRIPTS_DIR/../references" && pwd)/triage-skill.md"
  diff "$TEST_TEMP_DIR/.claude/skills/triage/SKILL.md" "$ref_file"
}

@test "install-triage-skill: outputs JSON with status and path" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/install-triage-skill.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
  assert_json_stdout_field '.path' '.claude/skills/triage/SKILL.md'
}
