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

@test "patch-quality-gate: no-op on new scoped gate" {
  cd "$TEST_TEMP_DIR"
  mkdir -p .claude/hooks
  cat > .claude/hooks/stop-quality-gate.sh <<'SCOPED'
#!/usr/bin/env bash
# Scoped quality gate. See skills/greenfield/scripts/generate-hooks.sh.
set -uo pipefail
echo '{"decision":"approve"}'
SCOPED
  run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'ok'
  local json
  json=$(_extract_json)
  local reason
  reason=$(echo "$json" | jq -r '.reason')
  [ "$reason" = "already-scoped" ]
}

@test "patch-quality-gate: no-op preserves the scoped gate byte-for-byte" {
  cd "$TEST_TEMP_DIR"
  mkdir -p .claude/hooks
  cat > .claude/hooks/stop-quality-gate.sh <<'SCOPED'
#!/usr/bin/env bash
# Scoped quality gate. See skills/greenfield/scripts/generate-hooks.sh.
set -uo pipefail
echo '{"decision":"approve"}'
SCOPED
  local before
  before=$(cat .claude/hooks/stop-quality-gate.sh)
  "$SCRIPTS_DIR/patch-quality-gate.sh" > /dev/null 2>&1
  local after
  after=$(cat .claude/hooks/stop-quality-gate.sh)
  [ "$before" = "$after" ]
}

@test "patch-quality-gate: reports legacy gate needs regeneration" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.status' 'skipped'
  local json
  json=$(_extract_json)
  local reason
  reason=$(echo "$json" | jq -r '.reason')
  [ "$reason" = "legacy-gate-needs-regeneration" ]
}

@test "patch-quality-gate: legacy gate body is not modified" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  local before
  before=$(cat .claude/hooks/stop-quality-gate.sh)
  "$SCRIPTS_DIR/patch-quality-gate.sh" > /dev/null 2>&1
  local after
  after=$(cat .claude/hooks/stop-quality-gate.sh)
  [ "$before" = "$after" ]
}

@test "patch-quality-gate: no .bak files remain" {
  copy_fixture "post-greenfield"
  cd "$TEST_TEMP_DIR"
  run "$SCRIPTS_DIR/patch-quality-gate.sh"
  [ "$status" -eq 0 ]
  local bak_count
  bak_count=$(find "$TEST_TEMP_DIR/.claude/hooks/" -name "*.bak" | wc -l)
  [ "$bak_count" -eq 0 ]
}
