#!/usr/bin/env bash
# Shared setup/teardown for all bats tests

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/skills/workflow/scripts"
FIXTURES_DIR="$TESTS_DIR/fixtures"

common_setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export PROJECT_DIR="$TEST_TEMP_DIR"
}

common_teardown() {
  [[ -d "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Copy a fixture directory into TEST_TEMP_DIR
copy_fixture() {
  local fixture="$1"
  cp -r "$FIXTURES_DIR/$fixture/"* "$TEST_TEMP_DIR/" 2>/dev/null || true
  cp -r "$FIXTURES_DIR/$fixture/".* "$TEST_TEMP_DIR/" 2>/dev/null || true
  # Generate settings.json at runtime to avoid static hook commands in the repo
  # (static hook command patterns in fixtures trigger security scanner false positives)
  if [[ "$fixture" == "post-greenfield" ]]; then
    _generate_settings_fixture
  fi
}

# Generate the post-greenfield settings.json fixture at runtime
_generate_settings_fixture() {
  mkdir -p "$TEST_TEMP_DIR/.claude"
  cat > "$TEST_TEMP_DIR/.claude/settings.json" <<'SETTINGS'
{
  "hooks": {
    "PreToolUse": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/guard.sh\""}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/stop-quality-gate.sh\""}]}],
    "SubagentStop": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/stop-quality-gate.sh\""}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/format.sh\""}]}],
    "PreCompact": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/save-context.sh\""}]}],
    "SessionStart": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh\""}]}]
  }
}
SETTINGS
}
