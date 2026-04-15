#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
  export STACK="typescript-node"
  export PKG_MANAGER="pnpm"
  export FORMATTER="prettier"
  export TEST_RUNNER="vitest"
  export TYPECHECKER=""
}

teardown() {
  common_teardown
}

@test "creates all 6 hook scripts" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT_DIR/.claude/hooks/guard.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/format.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/task-summary.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/save-context.sh"
  assert_file_exists "$PROJECT_DIR/.claude/hooks/session-start.sh"
}

@test "all hooks are executable" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_executable "$PROJECT_DIR/.claude/hooks/guard.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/format.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/task-summary.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/save-context.sh"
  assert_file_executable "$PROJECT_DIR/.claude/hooks/session-start.sh"
}

@test "stop-quality-gate.sh parses as valid bash" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  run bash -n "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh"
  [ "$status" -eq 0 ]
}

@test "stop-quality-gate.sh has scoped marker" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" '# Scoped quality gate'
}

@test "stop-quality-gate.sh builds CHANGED[] array" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'CHANGED=()'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'WORKING=()'
}

@test "stop-quality-gate.sh has bypass guards" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'stop_hook_active'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'hook-agent'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" '.workflow-running'
}

@test "stop-quality-gate.sh has per-file gitleaks loop" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'gitleaks detect --no-git --source='
}

@test "stop-quality-gate.sh has semgrep on CHANGED[]" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'semgrep --config=auto --quiet --error'
}

# --- Stack-specific bodies ---

@test "typescript-node hook runs oxlint and oxfmt" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'oxlint'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'oxfmt --check'
}

@test "typescript-node hook uses vitest related" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'vitest related'
}

@test "react stack emits JS/TS body" {
  export STACK="react"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'oxlint'
}

@test "nextjs stack emits JS/TS body" {
  export STACK="nextjs"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'oxlint'
}

@test "python stack emits ruff + ty/pyright/mypy body" {
  export STACK="python"
  export PKG_MANAGER="uv"
  export FORMATTER="ruff"
  export TEST_RUNNER="pytest"
  export TYPECHECKER="ty"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'ruff check'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'ruff format --check'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'ty check'
}

@test "python stack with pyright" {
  export STACK="python"
  export PKG_MANAGER="uv"
  export FORMATTER="ruff"
  export TYPECHECKER="pyright"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'TYPECHECKER=pyright'
}

@test "go stack emits gofmt + golangci-lint + go test body" {
  export STACK="go"
  export PKG_MANAGER="go"
  export FORMATTER="gofmt"
  export TEST_RUNNER="go-test"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'gofmt -l'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'golangci-lint run'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'go vet'
  assert_file_contains "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" 'go test'
}

# --- Runtime behavior ---

@test "hook approves when no files changed" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  cd "$PROJECT_DIR"
  git init -q
  git commit -q --allow-empty -m init
  result=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" <<< '{"stop_hook_active":false}')
  echo "$result" | grep -q '"decision":"approve"'
}

@test "hook bypasses when stop_hook_active is true" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  result=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" <<< '{"stop_hook_active":true}')
  echo "$result" | grep -q '"decision":"approve"'
}

@test "hook bypasses when .workflow-running file exists" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  cd "$PROJECT_DIR"
  git init -q
  git commit -q --allow-empty -m init
  mkdir -p .claude
  touch .claude/.workflow-running
  echo 'console.log(1)' > foo.ts
  result=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$PROJECT_DIR/.claude/hooks/stop-quality-gate.sh" <<< '{"stop_hook_active":false}')
  echo "$result" | grep -q '"decision":"approve"'
}

# --- guard.sh (unchanged behavior) ---

@test "guard.sh blocks destructive rm -rf" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  result=$(echo '{"tool_input":{"command":"rm -rf /"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"block"'
}

@test "guard.sh approves safe commands" {
  "$SCRIPTS_DIR/generate-hooks.sh" > /dev/null 2>&1
  result=$(echo '{"tool_input":{"command":"ls -la"}}' | bash "$PROJECT_DIR/.claude/hooks/guard.sh")
  echo "$result" | grep -q '"decision":"approve"'
}

# --- format.sh ---

@test "format.sh uses prettier command" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'npx prettier --write'
}

@test "format.sh uses ruff command" {
  export FORMATTER="ruff"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'ruff format'
}

@test "format.sh uses biome command" {
  export FORMATTER="biome"
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$PROJECT_DIR/.claude/hooks/format.sh" 'biomejs/biome format'
}

# --- Stdout contract ---

@test "stdout returns JSON with status ok" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
}

@test "stdout reports 6 files" {
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_count '.files | length' '6'
}

# --- Required env vars ---

@test "fails without PROJECT_DIR" {
  unset PROJECT_DIR
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}

@test "fails without STACK" {
  unset STACK
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}

@test "fails without PKG_MANAGER" {
  unset PKG_MANAGER
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}

@test "fails without FORMATTER" {
  unset FORMATTER
  run "$SCRIPTS_DIR/generate-hooks.sh"
  [ "$status" -eq 1 ]
}
