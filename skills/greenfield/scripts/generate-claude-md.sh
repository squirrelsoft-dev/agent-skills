#!/bin/bash
set -e

# generate-claude-md.sh
# Writes CLAUDE.md at the project root using interview answers.
# Outputs JSON status to stdout. Status messages to stderr.
#
# Env vars: PROJECT_DIR, PROJECT_NAME, PROJECT_DESCRIPTION, STACK,
#           INSTALL_CMD, DEV_CMD, BUILD_CMD, TEST_CMD, LINT_CMD, COMMIT_STYLE

[[ -z "${PROJECT_DIR:-}" ]] && echo "Error: PROJECT_DIR is required" >&2 && exit 1

[[ -z "${PROJECT_NAME:-}" ]] && echo "Error: PROJECT_NAME is required" >&2 && exit 1

PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION:-A new project.}"
STACK="${STACK:-typescript-node}"
INSTALL_CMD="${INSTALL_CMD:-npm install}"
DEV_CMD="${DEV_CMD:-npm run dev}"
BUILD_CMD="${BUILD_CMD:-npm run build}"
TEST_CMD="${TEST_CMD:-npm test}"
LINT_CMD="${LINT_CMD:-npm run lint}"
COMMIT_STYLE="${COMMIT_STYLE:-conventional}"

GENERATED_FILES=()

echo "Generating CLAUDE.md..." >&2

mkdir -p "$PROJECT_DIR"

cat > "$PROJECT_DIR/CLAUDE.md" <<CLAUDEMD
# ${PROJECT_NAME}

${PROJECT_DESCRIPTION}

## Stack
${STACK}

## Quick Start
\`\`\`bash
${INSTALL_CMD}
${DEV_CMD}
\`\`\`

## Commands
\`\`\`bash
${BUILD_CMD}        # production build
${TEST_CMD}         # run tests
${LINT_CMD}         # lint
\`\`\`

## Conventions
→ Rules: \`.claude/rules/\`
→ Commits: ${COMMIT_STYLE}

## Non-Negotiables
- Do not add dependencies without strong justification
- Run tests before marking any task complete
- Follow the rules in .claude/rules/

## Gotchas
- (add project-specific quirks here as you discover them)
CLAUDEMD
GENERATED_FILES+=("CLAUDE.md")

echo "Wrote CLAUDE.md" >&2

printf -v FILES_JSON '"%s",' "${GENERATED_FILES[@]}"
printf '{"status":"ok","files":[%s]}\n' "${FILES_JSON%,}"
