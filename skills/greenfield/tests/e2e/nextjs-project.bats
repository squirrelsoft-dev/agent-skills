#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  copy_fixture "nextjs"

  # Run stack detection
  cd "$TEST_TEMP_DIR"
  DETECT_OUTPUT="$("$SCRIPTS_DIR/detect-stack.sh" 2>/dev/null)"

  # Parse detection results
  export STACK=$(echo "$DETECT_OUTPUT" | jq -r '.stack')
  export PKG_MANAGER=$(echo "$DETECT_OUTPUT" | jq -r '.pkg_manager')
  export FORMATTER=$(echo "$DETECT_OUTPUT" | jq -r '.formatter')
  export TEST_RUNNER=$(echo "$DETECT_OUTPUT" | jq -r '.test_runner')

  # Interview-derived vars
  export PROJECT_NAME="My Next App"
  export PROJECT_DESCRIPTION="A Next.js application"
  export AGENT_TEAMS="false"
  export COMMIT_STYLE="conventional"

  # Stack-derived commands (from references/stacks/nextjs.md)
  export INSTALL_CMD="pnpm install"
  export DEV_CMD="pnpm dev"
  export BUILD_CMD="pnpm build"
  export TEST_CMD="pnpm vitest run"
  export LINT_CMD="pnpm lint"

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

@test "e2e/nextjs: stack detected as nextjs" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  assert_json_stdout_field '.stack' 'nextjs'
  assert_json_stdout_field '.framework' 'nextjs'
  assert_json_stdout_field '.lang' 'typescript'
  assert_json_stdout_field '.pkg_manager' 'pnpm'
  assert_json_stdout_field '.test_runner' 'vitest'
}

# --- settings.json ---

@test "e2e/nextjs: settings.json has all 6 hook events" {
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PreToolUse"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PostToolUse"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"Stop"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"SubagentStop"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"PreCompact"'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" '"SessionStart"'
}

@test "e2e/nextjs: settings.json references hook script paths" {
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'hooks/guard.sh'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'hooks/format.sh'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'hooks/stop-quality-gate.sh'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'hooks/task-summary.sh'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'hooks/save-context.sh'
  assert_file_contains "$PROJECT_DIR/.claude/settings.json" 'hooks/session-start.sh'
}

# --- settings.local.json ---

@test "e2e/nextjs: settings.local.json has pnpm permissions" {
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pnpm install:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(pnpm run *:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(node:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git add:*)'
  assert_file_contains "$PROJECT_DIR/.claude/settings.local.json" 'Bash(git commit:*)'
}

# --- Rules ---

@test "e2e/nextjs: all 5 rule files exist" {
  assert_file_exists "$PROJECT_DIR/.claude/rules/general.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/security.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/testing.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/frontend.md"
  assert_file_exists "$PROJECT_DIR/.claude/rules/api.md"
}

@test "e2e/nextjs: api.md has nextjs-specific paths" {
  assert_file_contains "$PROJECT_DIR/.claude/rules/api.md" 'app/api/**'
}

@test "e2e/nextjs: frontend.md has component rules" {
  assert_file_contains "$PROJECT_DIR/.claude/rules/frontend.md" 'Components should be focused'
}

# --- Hooks ---

@test "e2e/nextjs: all 6 hooks exist and are executable" {
  local hooks=(guard.sh format.sh stop-quality-gate.sh task-summary.sh save-context.sh session-start.sh)
  for hook in "${hooks[@]}"; do
    assert_file_exists "$PROJECT_DIR/.claude/hooks/$hook"
    assert_file_executable "$PROJECT_DIR/.claude/hooks/$hook"
  done
}

@test "e2e/nextjs: format.sh uses prettier" {
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'npx prettier --write'
}

@test "e2e/nextjs: stop-quality-gate.sh embeds pnpm commands" {
  # printf %q shell-quotes spaces, so check with regex
  assert_file_matches "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'LINT_CMD=.*pnpm.*lint'
  assert_file_matches "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'TEST_CMD=.*pnpm.*vitest.*run'
}

@test "e2e/nextjs: guard.sh blocks destructive commands" {
  result=$(echo '{"tool_input":{"command":"rm -rf /"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"block"'
}

@test "e2e/nextjs: guard.sh approves safe commands" {
  result=$(echo '{"tool_input":{"command":"pnpm install"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"approve"'
}

# --- CLAUDE.md ---

@test "e2e/nextjs: CLAUDE.md exists with correct content" {
  assert_file_exists "$PROJECT_DIR/CLAUDE.md"
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" '# My Next App'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'A Next.js application'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'nextjs'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm install'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'pnpm dev'
  assert_file_contains "$PROJECT_DIR/CLAUDE.md" 'conventional'
}

# --- .gitignore ---

@test "e2e/nextjs: .gitignore has all Claude Code entries" {
  assert_file_exists "$PROJECT_DIR/.gitignore"
  assert_file_contains "$PROJECT_DIR/.gitignore" 'CLAUDE.local.md'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/settings.local.json'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/logs/'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/scratch/'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/tasks/'
  assert_file_contains "$PROJECT_DIR/.gitignore" '.claude/specs/'
}
