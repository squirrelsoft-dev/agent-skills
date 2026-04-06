#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() { common_setup; }
teardown() { common_teardown; }

@test "patch-quality-gate: skips when stop-quality-gate.sh missing" {
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'skipped'
}

@test "patch-quality-gate: adds gitleaks block when GITLEAKS=yes" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=yes SEMGREP=no STACK=unknown run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/stop-quality-gate.sh" "gitleaks"
}

@test "patch-quality-gate: adds semgrep block when SEMGREP=yes" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=no SEMGREP=yes STACK=unknown run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/stop-quality-gate.sh" "semgrep"
}

@test "patch-quality-gate: adds npm audit block for nextjs stack" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=no SEMGREP=no STACK=nextjs run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_file_contains "$TEST_TEMP_DIR/.claude/hooks/stop-quality-gate.sh" "npm audit"
}

@test "patch-quality-gate: no npm audit for python stack" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=no SEMGREP=no STACK=python run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_file_not_contains "$TEST_TEMP_DIR/.claude/hooks/stop-quality-gate.sh" "npm audit"
}

@test "patch-quality-gate: blocks inserted before # Lint landmark" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=yes SEMGREP=no STACK=unknown run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  local gate="$TEST_TEMP_DIR/.claude/hooks/stop-quality-gate.sh"
  local gitleaks_line semgrep_line lint_line
  gitleaks_line=$(grep -n "gitleaks" "$gate" | head -1 | cut -d: -f1)
  lint_line=$(grep -n "# Lint" "$gate" | head -1 | cut -d: -f1)
  [ "$gitleaks_line" -lt "$lint_line" ]
}

@test "patch-quality-gate: idempotent — second run does not duplicate" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  local gate="$TEST_TEMP_DIR/.claude/hooks/stop-quality-gate.sh"
  GITLEAKS=yes SEMGREP=yes STACK=nextjs "$SCRIPTS_DIR/patch-quality-gate.sh" > /dev/null 2>&1
  local count_after_first
  count_after_first=$(grep -c "gitleaks" "$gate")
  GITLEAKS=yes SEMGREP=yes STACK=nextjs "$SCRIPTS_DIR/patch-quality-gate.sh" > /dev/null 2>&1
  local count_after_second
  count_after_second=$(grep -c "gitleaks" "$gate")
  [ "$count_after_first" -eq "$count_after_second" ]
}

@test "patch-quality-gate: no .bak files remain" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=yes SEMGREP=yes STACK=nextjs run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  local bak_count
  bak_count=$(find "$TEST_TEMP_DIR/.claude/hooks/" -name "*.bak" | wc -l)
  [ "$bak_count" -eq 0 ]
}

@test "patch-quality-gate: outputs JSON with patched list" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  GITLEAKS=yes SEMGREP=yes STACK=nextjs run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
  local json
  json=$(_extract_json)
  local patched
  patched=$(echo "$json" | jq -r '.patched')
  [[ "$patched" == *"gitleaks"* ]]
  [[ "$patched" == *"semgrep"* ]]
  [[ "$patched" == *"npm-audit"* ]]
}
