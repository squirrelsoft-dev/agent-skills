#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup

  # Run stack detection on empty dir
  cd "$TEST_TEMP_DIR"
  DETECT_OUTPUT="$("$SCRIPTS_DIR/detect-stack.sh" 2>/dev/null)"

  # Parse detection results — should all be unknown/none
  export STACK=$(echo "$DETECT_OUTPUT" | jq -r '.stack')
  export PKG_MANAGER=$(echo "$DETECT_OUTPUT" | jq -r '.pkg_manager')
  export FORMATTER=$(echo "$DETECT_OUTPUT" | jq -r '.formatter')
  export TEST_RUNNER=$(echo "$DETECT_OUTPUT" | jq -r '.test_runner')

  # Interview-derived vars
  export PROJECT_NAME="Empty Project"
  export PROJECT_DESCRIPTION="A blank project"
  export AGENT_TEAMS="false"
  export COMMIT_STYLE="conventional"

  # Fallback commands for unknown stack
  export INSTALL_CMD="echo 'no install configured'"
  export DEV_CMD="echo 'no dev configured'"
  export BUILD_CMD="echo 'no build configured'"
  export TEST_CMD="echo 'no tests configured'"
  export LINT_CMD="echo 'no lint configured'"

  # Hook generator env (new scoped-gate contract)
  export STACK="unknown"
  export PKG_MANAGER="unknown"
  export TEST_RUNNER=""
  export TYPECHECKER=""
}

teardown() {
  common_teardown
}

# --- Stack detection ---

@test "e2e/empty: detection returns unknown" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.stack' 'unknown'
  assert_json_stdout_field '.lang' 'unknown'
  assert_json_stdout_field '.pkg_manager' 'unknown'
  assert_json_stdout_field '.formatter' 'none'
  assert_json_stdout_field '.test_runner' 'none'
}

# --- All generators succeed ---

@test "e2e/empty: generate-settings.sh succeeds" {
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/settings.json"
  assert_file_exists "$PROJECT_DIR/.claude/settings.local.json"
}

@test "e2e/empty: settings.local.json has only git permissions" {
  "$SCRIPTS_DIR/generate-settings.sh" > /dev/null 2>&1
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git add:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git commit:*)'
  # Should not contain package manager specific permissions
  assert_file_not_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(npm'
  assert_file_not_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pnpm'
  assert_file_not_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(uv'
}

@test "e2e/empty: generate-rules.sh succeeds with 3 base files" {
  run "$SCRIPTS_DIR/generate-rules.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/rules/general.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/security.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/testing.md"
  [ ! -f "$PROJECT_DIR/.claude/rules/frontend.md" ]
  [ ! -f "$PROJECT_DIR/.claude/rules/api.md" ]
}

@test "e2e/empty: generate-hooks.sh succeeds" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/hooks/guard.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/guard.sh"
}

@test "e2e/empty: format.sh is no-op for unknown formatter" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'Unknown formatter'
}

@test "e2e/empty: generate-claude-md.sh succeeds" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/CLAUDE.md"
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" '# Empty Project'
}

@test "e2e/empty: generate-gitignore.sh succeeds" {
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.gitignore"
  assert_file_contains "$PROJECT_DIR/.gitignore" 'CLAUDE.local.md'
}
