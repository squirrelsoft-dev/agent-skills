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

# insert_before_lint: insert a block of text before the "# Lint" line in $GATE
# Works on both macOS and Linux (avoids sed -i portability issues)
insert_before_lint() {
  local block="$1"
  local block_file result_file
  block_file=$(mktemp)
  result_file=$(mktemp)
  printf '%s\n' "$block" > "$block_file"
  awk '/^# Lint/ { while ((getline line < "'"$block_file"'") > 0) print line; print "" } { print }' "$GATE" > "$result_file"
  mv "$result_file" "$GATE"
  chmod +x "$GATE"
  rm -f "$block_file"
}

if [ "$GITLEAKS" = "yes" ] && ! grep -q "gitleaks" "$GATE"; then
  read -r -d '' BLOCK << 'GITLEAKS_EOF' || true
# Secret detection (gitleaks)
if command -v gitleaks &>/dev/null; then
  if output=$(gitleaks detect --no-git --source=. 2>&1); then
    : # exit 0 = no leaks
  else
    details=$(echo "$output" | grep -iE "Secret|Finding|RuleID|Match" || true)
    [[ -n "$details" ]] && ERRORS+="\n## Secrets Detected (gitleaks)\n\`\`\`\n${details}\n\`\`\`\n"
  fi
fi
GITLEAKS_EOF
  insert_before_lint "$BLOCK"
  PATCHED+=("gitleaks")
  echo "Added gitleaks block" >&2
fi

if [ "$SEMGREP" = "yes" ] && ! grep -q "semgrep" "$GATE"; then
  read -r -d '' BLOCK << 'SEMGREP_EOF' || true
# SAST scan (semgrep)
if command -v semgrep &>/dev/null; then
  if output=$(semgrep --config=auto --quiet --json 2>/dev/null | jq -r ".results[] | \"\(.path):\(.start.line) \(.check_id)\"" 2>/dev/null); then
    [[ -n "$output" ]] && ERRORS+="\n## Security Issues\n\`\`\`\n${output}\n\`\`\`\n"
  fi
fi
SEMGREP_EOF
  insert_before_lint "$BLOCK"
  PATCHED+=("semgrep")
  echo "Added semgrep block" >&2
fi

if echo "$STACK" | grep -qE "nextjs|react|typescript-node" && ! grep -q "npm audit" "$GATE"; then
  read -r -d '' BLOCK << 'NPM_EOF' || true
# Dependency audit (npm)
if [[ -f "$CLAUDE_PROJECT_DIR/package.json" ]] && command -v npm &>/dev/null; then
  if output=$(npm audit --audit-level=high 2>&1) && echo "$output" | grep -q "high\|critical"; then
    ERRORS+="\n## Vulnerable Dependencies\n\`\`\`\n$(echo "$output" | tail -15)\n\`\`\`\n"
  fi
fi
NPM_EOF
  insert_before_lint "$BLOCK"
  PATCHED+=("npm-audit")
  echo "Added npm audit block" >&2
fi

PATCHED_STR=$(IFS=','; echo "${PATCHED[*]}")
echo "{\"status\":\"ok\",\"patched\":\"$PATCHED_STR\"}"
