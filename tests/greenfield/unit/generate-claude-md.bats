#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  export PROJECT_NAME="Test App"
  export PROJECT_DESCRIPTION="A test application"
  export STACK="nextjs"
  export INSTALL_CMD="pnpm install"
  export DEV_CMD="pnpm dev"
  export BUILD_CMD="pnpm build"
  export TEST_CMD="pnpm vitest run"
  export LINT_CMD="pnpm lint"
  export COMMIT_STYLE="conventional"
}

teardown() {
  common_teardown
}

@test "creates CLAUDE.md at project root" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/CLAUDE.md"
}

@test "CLAUDE.md contains project name as heading" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" '# Test App'
}

@test "CLAUDE.md contains description" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'A test application'
}

@test "CLAUDE.md contains stack" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'nextjs'
}

@test "CLAUDE.md contains install and dev commands" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm install'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm dev'
}

@test "CLAUDE.md contains build, test, and lint commands" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm build'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm vitest run'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm lint'
}

@test "CLAUDE.md contains commit style" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'conventional'
}

@test "uses defaults for optional vars" {
  export PROJECT_NAME="Minimal"
  unset PROJECT_DESCRIPTION STACK INSTALL_CMD DEV_CMD BUILD_CMD TEST_CMD LINT_CMD COMMIT_STYLE
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" '# Minimal'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'A new project.'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'npm install'
}

@test "stdout returns JSON with status ok" {
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}

@test "fails without PROJECT_DIR" {
  unset PROJECT_DIR
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 1 ]
}

@test "fails without PROJECT_NAME" {
  unset PROJECT_NAME
  run "$SCRIPTS_DIR/generate-claude-md.sh"
  [ "$status" -eq 1 ]
}
