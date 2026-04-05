#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install bats-core if not available
if ! command -v bats &>/dev/null; then
  BATS_DIR="$SCRIPT_DIR/.bats-core"
  if [ ! -d "$BATS_DIR" ]; then
    echo "Installing bats-core..." >&2
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$BATS_DIR" 2>&1 | tail -1
    git clone --depth 1 https://github.com/bats-core/bats-support.git "$SCRIPT_DIR/.bats-support" 2>&1 | tail -1
    git clone --depth 1 https://github.com/bats-core/bats-assert.git "$SCRIPT_DIR/.bats-assert" 2>&1 | tail -1
  fi
  export PATH="$BATS_DIR/bin:$PATH"
fi

# Verify jq is available
command -v jq &>/dev/null || { echo "Error: jq is required but not found" >&2; exit 1; }

echo "=== Running unit tests ==="
bats "$SCRIPT_DIR/unit/"

echo ""
echo "=== Running E2E tests ==="
bats "$SCRIPT_DIR/e2e/"

echo ""
echo "All tests passed."
