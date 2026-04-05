#!/bin/bash
set -e
# detect-tools.sh
# Detects available quality and workflow tools.
# Output: JSON to stdout. Status: stderr.

echo "Detecting tools..." >&2

GITLEAKS="no"; SEMGREP="no"; GH_CLI="no"; TRIVY="no"

command -v gitleaks &>/dev/null && GITLEAKS="yes"
command -v semgrep  &>/dev/null && SEMGREP="yes"
command -v gh       &>/dev/null && GH_CLI="yes"
command -v trivy    &>/dev/null && TRIVY="yes"

echo "gitleaks=$GITLEAKS semgrep=$SEMGREP gh=$GH_CLI trivy=$TRIVY" >&2

cat <<EOF
{
  "gitleaks": "$GITLEAKS",
  "semgrep": "$SEMGREP",
  "gh_cli": "$GH_CLI",
  "trivy": "$TRIVY"
}
EOF
