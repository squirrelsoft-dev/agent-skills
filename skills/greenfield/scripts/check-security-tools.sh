#!/bin/bash
set -e

# check-security-tools.sh
# Detects which security tools are installed and what package managers are available.
# Outputs JSON to stdout. Status messages to stderr.
#
# Env vars: STACK (optional — used to decide whether to check oxlint)

echo "Checking security tools..." >&2

STACK="${STACK:-unknown}"

# --- Detect system package manager ---
SYS_PKG="none"
command -v brew    &>/dev/null && SYS_PKG="brew"
command -v apt-get &>/dev/null && SYS_PKG="apt-get"
command -v dnf     &>/dev/null && SYS_PKG="dnf"
command -v pacman  &>/dev/null && SYS_PKG="pacman"

# --- Detect Python tool installer ---
PY_INSTALLER="none"
command -v uvx   &>/dev/null && PY_INSTALLER="uvx"
[ "$PY_INSTALLER" = "none" ] && command -v pipx &>/dev/null && PY_INSTALLER="pipx"
[ "$PY_INSTALLER" = "none" ] && command -v pip3 &>/dev/null && PY_INSTALLER="pip3"

# --- Check each tool ---
GITLEAKS="missing"
command -v gitleaks &>/dev/null && GITLEAKS="installed"

SEMGREP="missing"
command -v semgrep &>/dev/null && SEMGREP="installed"

TRIVY="missing"
command -v trivy &>/dev/null && TRIVY="installed"

# oxlint is Node/TypeScript only
OXLINT="skipped"
case "$STACK" in
  nextjs|react|typescript-node|node)
    OXLINT="missing"
    command -v oxlint &>/dev/null && OXLINT="installed"
    ;;
esac

echo "Security tool check complete" >&2

cat <<EOF
{
  "gitleaks": "$GITLEAKS",
  "semgrep": "$SEMGREP",
  "trivy": "$TRIVY",
  "oxlint": "$OXLINT",
  "sys_pkg_manager": "$SYS_PKG",
  "python_installer": "$PY_INSTALLER"
}
EOF
