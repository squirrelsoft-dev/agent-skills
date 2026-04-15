#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  copy_fixture "python"

  # Run stack detection
  cd "$TEST_TEMP_DIR"
  DETECT_OUTPUT="$("$SCRIPTS_DIR/detect-stack.sh" 2>/dev/null)"

  # Parse detection results
  export STACK=$(echo "$DETECT_OUTPUT" | jq -r '.stack')
  export PKG_MANAGER=$(echo "$DETECT_OUTPUT" | jq -r '.pkg_manager')
  export FORMATTER=$(echo "$DETECT_OUTPUT" | jq -r '.formatter')
  export TEST_RUNNER=$(echo "$DETECT_OUTPUT" | jq -r '.test_runner')

  # Interview-derived vars
  export PROJECT_NAME="My Python API"
  export PROJECT_DESCRIPTION="A FastAPI application"
  export AGENT_TEAMS="false"
  export COMMIT_STYLE="conventional"

  # Stack-derived commands
  export INSTALL_CMD="uv sync"
  export DEV_CMD="uv run uvicorn main:app --reload"
  export BUILD_CMD="uv build"
  export TEST_CMD="uv run pytest"
  export LINT_CMD="uv run ruff check ."

  # Hook generator env (new scoped-gate contract)
  export STACK="python"
  export PKG_MANAGER="uv"
  export TEST_RUNNER="pytest"
  export TYPECHECKER="pyright"

  # Run all generators
  "$SCRIPTS_DIR/generate-settings.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-rules.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-claude-md.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-gitignore.sh" > /dev/null 2>&1
}

teardown() {
  common_teardown
}

# --- Stack detection ---

@test "e2e/python: stack detected as python/fastapi/uv" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  assert_json_stdout_field '.stack' 'python'
  assert_json_stdout_field '.framework' 'fastapi'
  assert_json_stdout_field '.pkg_manager' 'uv'
  assert_json_stdout_field '.formatter' 'ruff'
  assert_json_stdout_field '.test_runner' 'pytest'
}

# --- settings.local.json ---

@test "e2e/python: settings.local.json has uv permissions" {
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(uv sync:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(uv run:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(python:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pytest:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(ruff:*)'
}

# --- Rules ---

@test "e2e/python: only 3 base rule files" {
  assert_file_exists "$PROJECT_DIR/.claude/rules/general.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/security.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/testing.md"
  [ ! -f "$PROJECT_DIR/.claude/rules/frontend.md" ]
  [ ! -f "$PROJECT_DIR/.claude/rules/api.md" ]
}

# --- Hooks ---

@test "e2e/python: all 6 hooks exist and are executable" {
  local hooks=(guard.sh format.sh stop-quality-gate.sh task-summary.sh save-context.sh session-start.sh)
  for hook in "${hooks[@]}"; do
    assert_file_exists "$PROJECT_DIR/.claude/hooks/$hook"
    assert_file_executable "$PROJECT_DIR/.claude/hooks/$hook"
  done
}

@test "e2e/python: format.sh uses ruff" {
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'ruff format'
}

@test "e2e/python: stop-quality-gate.sh embeds uv commands" {
  # printf %q shell-quotes spaces, so check with regex
  # New scoped Python hook uses ruff/pyright directly (not via uv/package manager)
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'STACK=python'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'ruff check'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'TYPECHECKER=pyright'
}

# --- CLAUDE.md ---

@test "e2e/python: CLAUDE.md has python-specific content" {
  assert_file_exists "$PROJECT_DIR/CLAUDE.md"
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" '# My Python API'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'python'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'uv sync'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'uv run pytest'
}

# --- .gitignore ---

@test "e2e/python: .gitignore has all entries" {
  assert_file_exists "$PROJECT_DIR/.gitignore"
  assert_file_contains "$PROJECT_DIR/.gitignore" 'CLAUDE.local.md'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/settings.local.json'
}
