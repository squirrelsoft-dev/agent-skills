#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  export STACK="python"
}

teardown() {
  common_teardown
}

@test "creates 3 base rules for any stack" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/rules/general.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/security.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/testing.md"
}

@test "general.md contains expected content" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/rules/general.md" 'Diagnose before fixing'
  assert_file_contains "$PROJECT_DIR/.claude/rules/general.md" 'Single responsibility'
}

@test "security.md contains expected content" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/rules/security.md" 'Never hardcode secrets'
}

@test "testing.md contains expected content" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/rules/testing.md" 'Test behavior, not implementation'
  assert_file_contains "$PROJECT_DIR/.claude/rules/testing.md" 'Mock external services'
}

@test "creates frontend.md and api.md for nextjs" {
  export STACK="nextjs"
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/rules/frontend.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/api.md"
  assert_file_contains "$PROJECT_DIR/.claude/rules/frontend.md" 'Components should be focused'
  assert_file_contains "$PROJECT_DIR/.claude/rules/api.md" 'app/api/**'
}

@test "creates frontend.md and api.md for react" {
  export STACK="react"
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/rules/frontend.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/api.md"
}

@test "creates api.md with server paths for typescript-node" {
  export STACK="typescript-node"
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/rules/api.md"
  assert_file_contains "$PROJECT_DIR/.claude/rules/api.md" 'src/server/**'
}

@test "does NOT create frontend.md for python" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.claude/rules/frontend.md" ]
}

@test "does NOT create api.md for python" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.claude/rules/api.md" ]
}

@test "stdout returns JSON with status ok" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}

@test "stdout reports correct file count for nextjs (5 files)" {
  export STACK="nextjs"
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_count '.files | length' '5'
}

@test "stdout reports correct file count for python (3 files)" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_count '.files | length' '3'
}

@test "fails without PROJECT_DIR" {
  unset PROJECT_DIR
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 1 ]
}

@test "fails without STACK" {
  unset STACK
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 1 ]
}
