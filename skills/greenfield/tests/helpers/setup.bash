#!/usr/bin/env bash
# Shared setup/teardown for all bats tests

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"
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
}
