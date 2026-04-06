#!/bin/bash
set -e
# analyze-git.sh
# Reads git history to detect commit style, branch naming, CI.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing git history..." >&2

COMMIT_STYLE="freeform"
BRANCH_PATTERN="unknown"
CI_PLATFORM="none"
HAS_PR_TEMPLATE="false"
HAS_CONTRIBUTING="false"
RECENT_COMMITS=""

[ -f ".github/pull_request_template.md" ] && HAS_PR_TEMPLATE="true"
{ [ -f "CONTRIBUTING.md" ] || [ -f ".github/CONTRIBUTING.md" ]; } && HAS_CONTRIBUTING="true"

[ -d ".github/workflows" ]    && CI_PLATFORM="github-actions"
[ -f ".gitlab-ci.yml" ]       && CI_PLATFORM="gitlab-ci"
[ -f "Jenkinsfile" ]           && CI_PLATFORM="jenkins"
[ -f ".circleci/config.yml" ] && CI_PLATFORM="circleci"

# Sample last 50 commits
if git log --oneline -50 &>/dev/null; then
  CONV_COUNT=$(git log --oneline -50 2>/dev/null | grep -cE "^[a-f0-9]+ (feat|fix|chore|docs|refactor|test|style|ci|perf)\(" || echo 0)
  TOTAL_COUNT=$(git log --oneline -50 2>/dev/null | wc -l | tr -d ' ')
  [ "$TOTAL_COUNT" -gt 0 ] && RATIO=$((CONV_COUNT * 100 / TOTAL_COUNT)) || RATIO=0
  [ "$RATIO" -ge 70 ] && COMMIT_STYLE="conventional"

  # Capture 3 real examples (escaped for JSON)
  RECENT_COMMITS=$(git log --oneline -3 2>/dev/null | sed 's/"/\\"/g' | awk '{msgs=msgs (NR>1?",":"") "\"" $0 "\""}END{print "["msgs"]"}')

  # Branch naming from recent branches
  BRANCH_SAMPLE=$(git branch -a 2>/dev/null | grep -v HEAD | head -10 | sed 's/[* ]//g' | tr '\n' ',')
  echo "Branch samples: $BRANCH_SAMPLE" >&2

  if echo "$BRANCH_SAMPLE" | grep -qE "[a-z]+/[A-Z]+-[0-9]+"; then
    BRANCH_PATTERN="type/TICKET-description"
  elif echo "$BRANCH_SAMPLE" | grep -qE "feature/|fix/|chore/"; then
    BRANCH_PATTERN="type/description"
  fi
fi

echo "Git analysis complete" >&2

cat <<EOF
{
  "commit_style": "$COMMIT_STYLE",
  "branch_pattern": "$BRANCH_PATTERN",
  "ci_platform": "$CI_PLATFORM",
  "has_pr_template": $HAS_PR_TEMPLATE,
  "has_contributing": $HAS_CONTRIBUTING,
  "recent_commits": ${RECENT_COMMITS:-[]}
}
EOF
