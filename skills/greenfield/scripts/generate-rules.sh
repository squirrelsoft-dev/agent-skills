#!/bin/bash
set -e

# generate-rules.sh
# Writes .claude/rules/ files based on the detected stack.
# Outputs JSON status to stdout. Status messages to stderr.
#
# Env vars: PROJECT_DIR, STACK

[[ -z "${PROJECT_DIR:-}" ]] && echo "Error: PROJECT_DIR is required" >&2 && exit 1

[[ -z "${STACK:-}" ]] && echo "Error: STACK is required" >&2 && exit 1

GENERATED_FILES=()

echo "Generating rules files..." >&2

mkdir -p "$PROJECT_DIR/.claude/rules"

# --- general.md (always) ---
cat > "$PROJECT_DIR/.claude/rules/general.md" <<'RULE'
# General Rules

- Diagnose before fixing: explain possible causes before changing code
- Functions no more than 50 lines; break larger ones into helpers
- Single responsibility per function and module
- Descriptive names: `calculateInvoiceTotal` not `calc`
- Remove commented-out code and debug statements before completing
- Never swallow exceptions silently
- Do not add dependencies without strong justification
- Always run tests before marking any task complete
RULE
GENERATED_FILES+=(".claude/rules/general.md")

# --- security.md (always) ---
cat > "$PROJECT_DIR/.claude/rules/security.md" <<'RULE'
# Security Rules

- Never hardcode secrets, API keys, or credentials — use environment variables
- Validate all external input at the boundary
- Use parameterized queries or ORM — never interpolate user input into SQL
- Sanitize output that reaches HTML/templates
- Never log sensitive data (passwords, tokens, PII)
RULE
GENERATED_FILES+=(".claude/rules/security.md")

# --- testing.md (always) ---
cat > "$PROJECT_DIR/.claude/rules/testing.md" <<'RULE'
---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/__tests__/**"
  - "tests/**"
  - "test/**"
---

# Testing Rules

- Test behavior, not implementation details
- Include edge cases: empty inputs, null values, boundary conditions
- Use descriptive test names that explain what is verified
- Mock external services — never hit real APIs in unit tests
- Run tests before marking any task complete
RULE
GENERATED_FILES+=(".claude/rules/testing.md")

# --- Stack-specific rules ---

case "$STACK" in
  nextjs|react)
    cat > "$PROJECT_DIR/.claude/rules/frontend.md" <<'RULE'
---
paths:
  - "src/components/**"
  - "src/app/**"
  - "app/**"
  - "pages/**"
---

# Frontend Rules

- Components should be focused and composable — one job per component
- Always include loading and error states
- Use semantic HTML and ARIA attributes for accessibility
- Keep component files under 200 lines — extract subcomponents when approaching limit
- Co-locate styles, types, and tests with their component
- Avoid prop drilling beyond 2 levels
RULE
    GENERATED_FILES+=(".claude/rules/frontend.md")

    cat > "$PROJECT_DIR/.claude/rules/api.md" <<'RULE'
---
paths:
  - "src/api/**"
  - "app/api/**"
  - "src/routes/**"
---

# API Rules

- Validate all input — use zod or equivalent
- Return consistent error shapes with appropriate HTTP status codes
- Never expose internal error details in production responses
- Include rate limiting on public-facing endpoints
RULE
    GENERATED_FILES+=(".claude/rules/api.md")
    ;;

  typescript-node)
    cat > "$PROJECT_DIR/.claude/rules/api.md" <<'RULE'
---
paths:
  - "src/api/**"
  - "src/routes/**"
  - "src/server/**"
---

# API Rules

- Validate all input — use zod or equivalent
- Return consistent error shapes with appropriate HTTP status codes
- Never expose internal error details in production responses
- Include rate limiting on public-facing endpoints
RULE
    GENERATED_FILES+=(".claude/rules/api.md")
    ;;
esac

echo "Wrote ${#GENERATED_FILES[@]} rules files" >&2

# Output JSON list of created files
printf -v FILES_JSON '"%s",' "${GENERATED_FILES[@]}"
printf '{"status":"ok","files":[%s]}\n' "${FILES_JSON%,}"
