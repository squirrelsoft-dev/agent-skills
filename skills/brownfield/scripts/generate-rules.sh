#!/bin/bash
set -e
# generate-rules.sh
# Writes .claude/rules/ files based on analysis JSON outputs.
# Uses real discovered values — not generic templates.

echo "Generating rules files..." >&2

mkdir -p .claude/rules

STACK="${STACK:-unknown}"
REPO_JSON="${REPO_JSON:-/tmp/bf-repo.json}"
CONVENTIONS_JSON="${CONVENTIONS_JSON:-/tmp/bf-conventions.json}"
TESTS_JSON="${TESTS_JSON:-/tmp/bf-tests.json}"

# Extract values from JSON
LINT_CMD=$(jq -r '.commands.lint // ""' "$REPO_JSON" 2>/dev/null || echo "")
TEST_CMD=$(jq -r '.commands.test // ""' "$REPO_JSON" 2>/dev/null || echo "")
BUILD_CMD=$(jq -r '.commands.build // ""' "$REPO_JSON" 2>/dev/null || echo "")
INSTALL_CMD=$(jq -r '.commands.install // ""' "$REPO_JSON" 2>/dev/null || echo "")
PKG_MANAGER=$(jq -r '.pkg_manager // ""' "$REPO_JSON" 2>/dev/null || echo "")
FILE_NAMING=$(jq -r '.file_naming // "unknown"' "$CONVENTIONS_JSON" 2>/dev/null || echo "unknown")
IMPORT_STYLE=$(jq -r '.import_style // "unknown"' "$CONVENTIONS_JSON" 2>/dev/null || echo "unknown")
QUOTE_STYLE=$(jq -r '.quote_style // "unknown"' "$CONVENTIONS_JSON" 2>/dev/null || echo "unknown")
SEMICOLONS=$(jq -r '.semicolons // "unknown"' "$CONVENTIONS_JSON" 2>/dev/null || echo "unknown")
PATH_ALIASES=$(jq -r '.path_aliases // ""' "$CONVENTIONS_JSON" 2>/dev/null || echo "")
TEST_FRAMEWORK=$(jq -r '.framework // "none"' "$TESTS_JSON" 2>/dev/null || echo "none")
TEST_LOCATION=$(jq -r '.file_location // "unknown"' "$TESTS_JSON" 2>/dev/null || echo "unknown")
TEST_PATTERN=$(jq -r '.file_pattern // "unknown"' "$TESTS_JSON" 2>/dev/null || echo "unknown")

# --- general.md ---
cat > .claude/rules/general.md <<RULE
# General Rules

- Diagnose before fixing: explain possible causes before changing code
- Functions no more than 50 lines; break larger ones into helpers
- Single responsibility per function and module
- Remove commented-out code and debug statements before completing
- Never swallow exceptions silently
- Do not add dependencies without strong justification
- Always run tests before marking any task complete
RULE

# --- conventions.md ---
cat > .claude/rules/conventions.md <<RULE
# Code Conventions

## File Naming
${FILE_NAMING}

## Import Style
${IMPORT_STYLE} imports${PATH_ALIASES:+ — path aliases: $PATH_ALIASES}

## Formatting
- Quotes: ${QUOTE_STYLE}
- Semicolons: ${SEMICOLONS}
- Run formatter with: ${LINT_CMD:-see package.json}

## Key Rule
Match the style of surrounding files when making changes.
RULE

# --- testing.md ---
TEST_PATH_GLOB=""
[ "$TEST_LOCATION" = "co-located" ] && TEST_PATH_GLOB='paths:
  - "**/*.test.*"
  - "**/*.spec.*"'
[ "$TEST_LOCATION" = "separate-directory" ] && TEST_PATH_GLOB='paths:
  - "tests/**"
  - "__tests__/**"'

cat > .claude/rules/testing.md <<RULE
---
${TEST_PATH_GLOB}
---

# Testing Rules

## Framework
${TEST_FRAMEWORK}

## Test File Locations
${TEST_PATTERN}

## Run Tests
\`\`\`bash
${TEST_CMD}
\`\`\`

## Rules
- Test behavior, not implementation details
- Include edge cases: empty inputs, null values, boundary conditions
- Use descriptive test names that explain what is verified
- Mock external services — never hit real APIs in unit tests
- Run tests before marking any task complete
RULE

# --- security.md ---
cat > .claude/rules/security.md <<'RULE'
# Security Rules

- Never hardcode secrets, API keys, or credentials — use environment variables
- Validate all external input at the boundary
- Use parameterized queries or ORM — never interpolate user input into SQL
- Sanitize output that reaches HTML/templates
- Never log sensitive data (passwords, tokens, PII)
RULE

echo "Rules files written" >&2
echo '{"status":"ok","files":["general.md","conventions.md","testing.md","security.md"]}'
