#!/bin/bash
set -e

# install-security-tools.sh
# Installs missing security tools using the best available package manager.
# Outputs JSON to stdout. Status messages to stderr.
#
# Env vars: STACK (optional — for oxlint relevance)
# Reads check-security-tools.sh JSON from stdin or TOOLS_JSON env var.

echo "Installing security tools..." >&2

STACK="${STACK:-unknown}"
TOOLS_JSON="${TOOLS_JSON:-}"

if [ -z "$TOOLS_JSON" ]; then
  echo "Error: TOOLS_JSON is required (path to check-security-tools.sh output)" >&2
  exit 1
fi

SYS_PKG=$(jq -r '.sys_pkg_manager' "$TOOLS_JSON" 2>/dev/null || echo "none")
PY_INSTALLER=$(jq -r '.python_installer' "$TOOLS_JSON" 2>/dev/null || echo "none")
GITLEAKS_STATUS=$(jq -r '.gitleaks' "$TOOLS_JSON" 2>/dev/null || echo "missing")
SEMGREP_STATUS=$(jq -r '.semgrep' "$TOOLS_JSON" 2>/dev/null || echo "missing")
TRIVY_STATUS=$(jq -r '.trivy' "$TOOLS_JSON" 2>/dev/null || echo "missing")
OXLINT_STATUS=$(jq -r '.oxlint' "$TOOLS_JSON" 2>/dev/null || echo "skipped")

INSTALLED=()
FAILED=()

# --- gitleaks ---
if [ "$GITLEAKS_STATUS" = "missing" ]; then
  echo "Installing gitleaks..." >&2
  if [ "$SYS_PKG" = "brew" ]; then
    if brew install gitleaks 2>&1 >&2; then
      INSTALLED+=("gitleaks")
    else
      echo "  Failed to install gitleaks via brew." >&2
      echo "  Manual install: https://github.com/gitleaks/gitleaks/releases" >&2
      FAILED+=("gitleaks")
    fi
  else
    echo "  gitleaks requires manual install (no brew detected)." >&2
    echo "  Download from: https://github.com/gitleaks/gitleaks/releases" >&2
    FAILED+=("gitleaks")
  fi
fi

# --- semgrep ---
if [ "$SEMGREP_STATUS" = "missing" ]; then
  echo "Installing semgrep..." >&2
  SEMGREP_DONE="false"
  if [ "$PY_INSTALLER" = "uvx" ]; then
    if uv tool install semgrep 2>&1 >&2; then
      INSTALLED+=("semgrep"); SEMGREP_DONE="true"
    fi
  fi
  if [ "$SEMGREP_DONE" = "false" ] && [ "$PY_INSTALLER" = "pipx" ]; then
    if pipx install semgrep 2>&1 >&2; then
      INSTALLED+=("semgrep"); SEMGREP_DONE="true"
    fi
  fi
  if [ "$SEMGREP_DONE" = "false" ] && command -v pip3 &>/dev/null; then
    if pip3 install semgrep 2>&1 >&2; then
      INSTALLED+=("semgrep"); SEMGREP_DONE="true"
    fi
  fi
  if [ "$SEMGREP_DONE" = "false" ] && [ "$SYS_PKG" = "brew" ]; then
    if brew install semgrep 2>&1 >&2; then
      INSTALLED+=("semgrep"); SEMGREP_DONE="true"
    fi
  fi
  if [ "$SEMGREP_DONE" = "false" ]; then
    echo "  Failed to install semgrep." >&2
    echo "  Manual install: uv tool install semgrep / pipx install semgrep / pip3 install semgrep" >&2
    FAILED+=("semgrep")
  fi
fi

# --- trivy ---
if [ "$TRIVY_STATUS" = "missing" ]; then
  echo "Installing trivy..." >&2
  if [ "$SYS_PKG" = "brew" ]; then
    if brew install trivy 2>&1 >&2; then
      INSTALLED+=("trivy")
    else
      echo "  Failed to install trivy via brew." >&2
      echo "  Manual install: https://trivy.dev" >&2
      FAILED+=("trivy")
    fi
  else
    echo "  trivy requires manual install (no brew detected)." >&2
    echo "  Download from: https://trivy.dev" >&2
    FAILED+=("trivy")
  fi
fi

# --- oxlint (Node/TS stacks only) ---
if [ "$OXLINT_STATUS" = "missing" ]; then
  echo "Installing oxlint..." >&2
  if command -v npm &>/dev/null; then
    if npm install -g oxlint 2>&1 >&2; then
      INSTALLED+=("oxlint")
    else
      echo "  Failed to install oxlint via npm." >&2
      echo "  Manual install: npm install -g oxlint" >&2
      FAILED+=("oxlint")
    fi
  else
    echo "  npm not available — cannot install oxlint." >&2
    FAILED+=("oxlint")
  fi
fi

echo "Installation complete" >&2

# Build JSON output
printf -v INST_JSON '"%s",' "${INSTALLED[@]}"
printf -v FAIL_JSON '"%s",' "${FAILED[@]}"
INST_JSON="${INST_JSON%,}"
FAIL_JSON="${FAIL_JSON%,}"

cat <<EOF
{
  "status": "ok",
  "installed": [${INST_JSON}],
  "failed": [${FAIL_JSON}]
}
EOF
