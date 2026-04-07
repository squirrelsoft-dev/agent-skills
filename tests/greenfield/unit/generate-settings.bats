#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  export PKG_MANAGER="npm"
  export AGENT_TEAMS="false"
}

teardown() {
  common_teardown
}

@test "creates settings.json with hooks" {
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/settings.json"
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"hooks"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PreToolUse"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PostToolUse"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"Stop"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"SubagentStop"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PreCompact"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"SessionStart"'
}

@test "settings.json excludes env block when AGENT_TEAMS=false" {
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_not_contains "$PROJECT_DIR/.claude/settings.json" 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "settings.json includes env block when AGENT_TEAMS=true" {
  export AGENT_TEAMS="true"
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "creates settings.local.json with npm permissions" {
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/settings.local.json"
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(npm install:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(npm run *:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(node:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(npx tsc:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git add:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git commit:*)'
}

@test "creates settings.local.json with pnpm permissions" {
  export PKG_MANAGER="pnpm"
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pnpm install:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pnpm run *:*)'
}

@test "creates settings.local.json with uv permissions" {
  export PKG_MANAGER="uv"
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(uv sync:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(uv run:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(python:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pytest:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(ruff:*)'
}

@test "creates settings.local.json with pip permissions" {
  export PKG_MANAGER="pip"
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pip install:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(python:*)'
}

@test "handles unknown pkg_manager with git-only permissions" {
  export PKG_MANAGER="unknown"
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git add:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git commit:*)'
}

@test "stdout returns JSON with status ok" {
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}

@test "fails without PROJECT_DIR" {
  unset PROJECT_DIR
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 1 ]
}

@test "fails without PKG_MANAGER" {
  unset PKG_MANAGER
  run "$SCRIPTS_DIR/generate-settings.sh"
  [ "$status" -eq 1 ]
}
