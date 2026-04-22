#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "detects nextjs stack from package.json with pnpm" {
  copy_fixture "nextjs"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.stack' 'nextjs'
  assert_json_stdout_field '.framework' 'nextjs'
  assert_json_stdout_field '.lang' 'typescript'
  assert_json_stdout_field '.pkg_manager' 'pnpm'
  assert_json_stdout_field '.test_runner' 'vitest'
  assert_json_stdout_field '.has_typescript' 'true'
}

@test "detects oxfmt as default formatter for node" {
  copy_fixture "nextjs"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.formatter' 'oxfmt'
}

@test "detects python stack from pyproject.toml" {
  copy_fixture "python"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.stack' 'python'
  assert_json_stdout_field '.framework' 'fastapi'
  assert_json_stdout_field '.lang' 'python'
  assert_json_stdout_field '.pkg_manager' 'uv'
  assert_json_stdout_field '.formatter' 'ruff'
  assert_json_stdout_field '.test_runner' 'pytest'
}

@test "returns unknown for empty directory" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.stack' 'unknown'
  assert_json_stdout_field '.lang' 'unknown'
  assert_json_stdout_field '.pkg_manager' 'unknown'
  assert_json_stdout_field '.formatter' 'none'
  assert_json_stdout_field '.test_runner' 'none'
}

@test "stdout is valid JSON" {
  copy_fixture "nextjs"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  # Extract JSON block from mixed output and validate
  local json_block
  json_block="$(echo "$output" | sed -n '/^{/,/^}/p')"
  echo "$json_block" | jq . > /dev/null 2>&1
}

@test "has_typescript is false without tsconfig" {
  mkdir -p "$TEST_TEMP_DIR"
  cat > "$TEST_TEMP_DIR/package.json" <<'EOF'
{"name":"test","dependencies":{"express":"4.0.0"}}
EOF
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.has_typescript' 'false'
  assert_json_stdout_field '.lang' 'javascript'
}

@test "detects npm when no lockfile present" {
  mkdir -p "$TEST_TEMP_DIR"
  cat > "$TEST_TEMP_DIR/package.json" <<'EOF'
{"name":"test","dependencies":{"next":"14.0.0"}}
EOF
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/detect-stack.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.pkg_manager' 'npm'
}
