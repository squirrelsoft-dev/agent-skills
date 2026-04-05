#!/bin/bash
set -e
# patch-quality-gate.sh
# Adds quality tool scan blocks to .claude/hooks/stop-quality-gate.sh
# GITLEAKS: "yes" or "no"
# SEMGREP: "yes" or "no"
# STACK: detected stack (for npm audit block)

GATE=".claude/hooks/stop-quality-gate.sh"

if [ ! -f "$GATE" ]; then
  echo "stop-quality-gate.sh not found — skipping patch" >&2
  echo '{"status":"skipped","reason":"gate not found"}'
  exit 0
fi

GITLEAKS="${GITLEAKS:-no}"
SEMGREP="${SEMGREP:-no}"
STACK="${STACK:-unknown}"
PATCHED=()

if [ "$GITLEAKS" = "yes" ] && ! grep -q "gitleaks" "$GATE"; then
  BLOCK='# Secret detection (gitleaks)\nif command -v gitleaks &>/dev/null; then\n  if output=$(gitleaks detect --no-git --source=. --verbose 2>&1 | grep -E "Secret|Finding|leak"); then\n    [[ -n "$output" ]] && ERRORS+="\\n## Secrets Detected\\n\\`\\`\\`\\n${output}\\n\\`\\`\\`\\n"\n  fi\nfi'
  sed -i.bak "/# Lint/i $BLOCK" "$GATE"
  PATCHED+=("gitleaks")
  echo "Added gitleaks block" >&2
fi

if [ "$SEMGREP" = "yes" ] && ! grep -q "semgrep" "$GATE"; then
  BLOCK='# SAST scan (semgrep)\nif command -v semgrep &>/dev/null; then\n  if output=$(semgrep --config=auto --quiet --json 2>/dev/null | jq -r ".results[] | \"\(.path):\(.start.line) \(.check_id)\"" 2>/dev/null); then\n    [[ -n "$output" ]] && ERRORS+="\\n## Security Issues\\n\\`\\`\\`\\n${output}\\n\\`\\`\\`\\n"\n  fi\nfi'
  sed -i.bak "/# Lint/i $BLOCK" "$GATE"
  PATCHED+=("semgrep")
  echo "Added semgrep block" >&2
fi

if echo "$STACK" | grep -qE "nextjs|react|typescript-node" && ! grep -q "npm audit" "$GATE"; then
  BLOCK='# Dependency audit (npm)\nif [[ -f "$CLAUDE_PROJECT_DIR/package.json" ]] && command -v npm &>/dev/null; then\n  if output=$(npm audit --audit-level=high 2>&1) && echo "$output" | grep -q "high\\|critical"; then\n    ERRORS+="\\n## Vulnerable Dependencies\\n\\`\\`\\`\\n$(echo "$output" | tail -15)\\n\\`\\`\\`\\n"\n  fi\nfi'
  sed -i.bak "/# Lint/i $BLOCK" "$GATE"
  PATCHED+=("npm-audit")
  echo "Added npm audit block" >&2
fi

rm -f "$GATE.bak"
PATCHED_STR=$(IFS=','; echo "${PATCHED[*]}")
echo "{\"status\":\"ok\",\"patched\":\"$PATCHED_STR\"}"
