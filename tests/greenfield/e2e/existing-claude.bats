#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  copy_fixture "existing-claude"

  # Set env vars for generators
  export PKG_MANAGER="npm"
  export AGENT_TEAMS="false"
  export STACK="typescript-node"
  export LINT_CMD="npm run lint"
  export TEST_CMD="npm test"
  export FORMATTER="prettier"
  export TEST_RUNNER="vitest"
  export TYPECHECKER=""
  export PROJECT_NAME="Existing Project"
  export PROJECT_DESCRIPTION="Project with existing .claude dir"
  export INSTALL_CMD="npm install"
  export DEV_CMD="npm run dev"
  export BUILD_CMD="npm run build"
  export COMMIT_STYLE="conventional"
}

teardown() {
  common_teardown
}

@test "e2e/existing: .claude/settings.json exists before generation" {
  assert_file_exists "$PROJECT_DIR/.claude/settings.json"
  # Verify it's the dummy content
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '{}'
}

@test "e2e/existing: generate-settings.sh overwrites existing settings.json" {
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  # Should now contain hooks, not just {}
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"hooks"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PreToolUse"'
}

@test "e2e/existing: all generators succeed with pre-existing .claude/" {
  "$SCRIPTS_DIR/generate-settings.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-rules.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  "$SCRIPTS_DIR/generate-claude-md.sh" > /dev/null 2>&1
  run "$SCRIPTS_DIR/generate-gitignore.sh"
  [ "$status" -eq 0 ]

  # Verify full output exists
  assert_file_exists "$PROJECT_DIR/.claude/settings.json"
  assert_file_exists "$PROJECT_DIR/.claude/settings.local.json"
  assert_file_exists "$PROJECT_DIR/.claude/rules/general.md"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/guard.sh"
  assert_file_exists "$PROJECT_DIR/CLAUDE.md"
  assert_file_exists "$PROJECT_DIR/.gitignore"
}

@test "e2e/existing: settings.local.json created alongside overwritten settings.json" {
  "$SCRIPTS_DIR/generate-settings.sh" > /dev/null 2>&1
  assert_file_exists "$PROJECT_DIR/.claude/settings.local.json"
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(npm install:*)'
}

@test "e2e/existing: typescript-node stack gets api.md but no frontend.md" {
  "$SCRIPTS_DIR/generate-rules.sh" > /dev/null 2>&1
  assert_file_exists "$PROJECT_DIR/.claude/rules/api.md"
  assert_file_contains "$PROJECT_DIR/.claude/rules/api.md" 'src/server/**'
  [ ! -f "$PROJECT_DIR/.claude/rules/frontend.md" ]
}
