#!/usr/bin/env bash
set -euo pipefail
ERRORS=""

# Lint
if ! output=$(npm run lint 2>&1); then
  ERRORS+="\n## Lint\n\`\`\`\n${output}\n\`\`\`\n"
fi

# Tests
if ! output=$(npm test 2>&1); then
  ERRORS+="\n## Tests\n\`\`\`\n${output}\n\`\`\`\n"
fi

if [[ -n "$ERRORS" ]]; then
  printf "Quality gate failed:\n%b" "$ERRORS" >&2
  exit 2
fi
exit 0
