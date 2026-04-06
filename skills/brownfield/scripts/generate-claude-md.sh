#!/bin/bash
set -e
# generate-claude-md.sh
# Writes CLAUDE.md using real values from analysis JSON.

echo "Generating CLAUDE.md..." >&2

REPO_JSON="${REPO_JSON:-/tmp/bf-repo.json}"
GIT_JSON="${GIT_JSON:-/tmp/bf-git.json}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PWD")}"
COMMIT_STYLE="${COMMIT_STYLE:-detected}"

INSTALL_CMD=$(jq -r '.commands.install // ""' "$REPO_JSON" 2>/dev/null || echo "")
DEV_CMD=$(jq -r '.commands.dev // ""' "$REPO_JSON" 2>/dev/null || echo "")
BUILD_CMD=$(jq -r '.commands.build // ""' "$REPO_JSON" 2>/dev/null || echo "")
TEST_CMD=$(jq -r '.commands.test // ""' "$REPO_JSON" 2>/dev/null || echo "")
LINT_CMD=$(jq -r '.commands.lint // ""' "$REPO_JSON" 2>/dev/null || echo "")
STACK=$(jq -r '.stack // "unknown"' "$REPO_JSON" 2>/dev/null || echo "unknown")
FRAMEWORK=$(jq -r '.framework // ""' "$REPO_JSON" 2>/dev/null || echo "")
PKG_MANAGER=$(jq -r '.pkg_manager // ""' "$REPO_JSON" 2>/dev/null || echo "")

# Real commit examples from git log
COMMIT_EXAMPLES=$(jq -r '.recent_commits[]? // empty' "$GIT_JSON" 2>/dev/null | head -3 | sed 's/^/  /' || echo "  (no commits yet)")

cat > CLAUDE.md <<CLAUDEMD
# ${PROJECT_NAME}

## Stack
${STACK}${FRAMEWORK:+ / $FRAMEWORK} · ${PKG_MANAGER}

## Quick Start
\`\`\`bash
${INSTALL_CMD}
${DEV_CMD}
\`\`\`

## Commands
\`\`\`bash
${BUILD_CMD:-# no build command detected}
${TEST_CMD:-# no test command detected}
${LINT_CMD:-# no lint command detected}
\`\`\`

## Conventions
→ Full rules: \`.claude/rules/\`
→ Commits: ${COMMIT_STYLE}

Recent commit examples:
${COMMIT_EXAMPLES}

## Non-Negotiables
- Do not add dependencies without strong justification
- Run tests before marking any task complete
- Follow the rules in .claude/rules/ — they reflect how this project was built

## Gotchas
- (add project-specific quirks here as you discover them)
CLAUDEMD

echo "CLAUDE.md written" >&2
echo '{"status":"ok","files":["CLAUDE.md"]}'
