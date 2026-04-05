# Greenfield Skill — Implementation Plan

This document tells Claude Code exactly what files to create and where.
Follow each step in order. Do not skip steps.

---

## Overview

The greenfield skill sets up Claude Code configuration for a brand new project.
It runs a developer interview, detects the stack, then generates all .claude/
configuration files tailored to that project.

The skill lives at: `skills/greenfield/`

---

## Directory Structure to Create

```
skills/
└── greenfield/
    ├── SKILL.md                          ← main skill file (orchestrator)
    ├── scripts/
    │   ├── detect-stack.sh               ← detects stack from project files
    │   ├── generate-settings.sh          ← writes settings.json + settings.local.json
    │   ├── generate-rules.sh             ← writes .claude/rules/*.md files
    │   ├── generate-hooks.sh             ← writes .claude/hooks/*.sh files + chmod +x
    │   ├── generate-claude-md.sh         ← writes CLAUDE.md
    │   └── generate-gitignore.sh         ← appends Claude entries to .gitignore
    └── references/
        ├── interview.md                  ← full interview question set
        ├── artifact-specs.md             ← exact content for every generated file
        ├── ci-templates.md               ← GitHub Actions workflow templates
        └── stacks/
            ├── nextjs-react.md            ← Next.js / React conventions + commands
            ├── typescript-node.md        ← Node.js/TypeScript conventions
            ├── python.md                 ← Python conventions
            └── go.md                    ← Go conventions
```

---

## Step 1 — Create `skills/greenfield/SKILL.md`

This is the main file Claude Code reads when the skill is triggered.
Keep it under 500 lines. Heavy content lives in `references/`.

Content to write:

```markdown
---
name: greenfield
description: >
  Set up Claude Code configuration for a brand new project from scratch.
  Runs a developer interview, detects the stack, then generates CLAUDE.md,
  .claude/rules/, .claude/hooks/, settings.json, and settings.local.json —
  all tailored to the actual stack. Trigger phrases: "set up Claude Code",
  "initialize Claude", "run greenfield setup", "/greenfield", "configure
  Claude for this project", "set up this new project".
---

# Greenfield Setup

Configures Claude Code for a new project. Everything is generated on the fly
based on the actual stack and developer answers — not copied from generic templates.

**Scope:** Generates project foundation only:
- CLAUDE.md, .claude/rules/, .claude/hooks/, settings.json, settings.local.json, .gitignore
- Optional: git init + first commit, GitHub Actions CI workflows

Run `/workflow` after this to install development commands and agents.

---

## Step 1 — Preflight

Check for existing setup:

```bash
bash .claude/skills/greenfield/scripts/detect-stack.sh
```

If `.claude/` already exists, ask:
> "A `.claude/` directory already exists. This will overwrite it.
> Continue, or run `/brownfield` instead to analyze what's already here?"

Wait for confirmation before proceeding.

---

## Step 2 — Stack Detection

The detect-stack.sh script outputs a JSON object with detected values.
Read and parse the output. If stack is "unknown", ask the developer:
> "I couldn't detect your stack. What are you building?
> (e.g. Next.js, React, Node.js API, Python, Go, Rust, .NET)"

---

## Step 3 — Developer Interview

Present all questions at once before generating anything.
Load the full question set from:
`.claude/skills/greenfield/references/interview.md`

Core questions (always ask):
1. Project name
2. Project description (1–2 sentences)
3. Confirm detected stack — show what was found, ask to correct
4. Git setup — init + first commit? (yes / already done / skip)
5. Agent teams — enable CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS? (yes / no)
6. Commit style — conventional commits or free-form?
7. CI/CD — scaffold GitHub Actions? (yes — ask which / no)

Wait for developer response before proceeding to Step 4.

---

## Step 4 — Load Stack Knowledge

Read the appropriate stack reference file:

| Stack | File |
|---|---|
| Next.js | `.claude/skills/greenfield/references/stacks/nextjs-react.md` |
| React | `.claude/skills/greenfield/references/stacks/nextjs-react.md` |
| Node.js / TypeScript | `.claude/skills/greenfield/references/stacks/typescript-node.md` |
| Python | `.claude/skills/greenfield/references/stacks/python.md` |
| Go | `.claude/skills/greenfield/references/stacks/go.md` |
| Unknown/other | Use Claude's training knowledge for that stack |

---

## Step 5 — Generate All Artifacts

Run each script in sequence (or spawn as subagents in parallel if available).
Each script reads its inputs from environment variables set before calling it.

### 5a — Settings

```bash
PROJECT_NAME="[from interview]" \
AGENT_TEAMS="[true/false]" \
PKG_MANAGER="[npm/pnpm/yarn/bun/pip/go/cargo]" \
LINT_CMD="[detected lint command]" \
TEST_CMD="[detected test command]" \
bash .claude/skills/greenfield/scripts/generate-settings.sh
```

### 5b — Rules

```bash
STACK="[detected stack]" \
PROJECT_DIR="[path]" \
bash .claude/skills/greenfield/scripts/generate-rules.sh
```

### 5c — Hooks

```bash
LINT_CMD="[detected lint command]" \
TEST_CMD="[detected test command]" \
FORMATTER="[prettier/biome/ruff/gofmt]" \
bash .claude/skills/greenfield/scripts/generate-hooks.sh
```

### 5d — CLAUDE.md

```bash
PROJECT_NAME="[from interview]" \
PROJECT_DESCRIPTION="[from interview]" \
STACK="[detected stack]" \
INSTALL_CMD="[install command]" \
DEV_CMD="[dev command]" \
BUILD_CMD="[build command]" \
TEST_CMD="[test command]" \
LINT_CMD="[lint command]" \
COMMIT_STYLE="[conventional/freeform]" \
bash .claude/skills/greenfield/scripts/generate-claude-md.sh
```

### 5e — .gitignore

```bash
bash .claude/skills/greenfield/scripts/generate-gitignore.sh
```

---

## Step 6 — Git Setup (if requested)

```bash
git init
git add -A
git commit -m "chore: initialize project with Claude Code configuration"
```

If conventional commits: use `chore(claude): initialize Claude Code configuration`

---

## Step 7 — CI/CD (if requested)

Load templates from:
`.claude/skills/greenfield/references/ci-templates.md`

Generate `.github/workflows/` files using the exact commands from the interview.

---

## Step 8 — Completion

Tell the developer what was created:

```
✅ Greenfield Setup Complete — [Project Name]

Generated:
- CLAUDE.md
- .claude/settings.json        (agent teams: yes/no)
- .claude/settings.local.json
- .claude/rules/               [list files]
- .claude/hooks/               [list scripts]

Next steps:
1. npx skills add squirrelsoft-dev/skills@workflow
2. Launch Claude Code
3. Run /workflow to install commands and agents
4. Restart Claude Code
```

---

## Reference Files

- Full interview questions: `references/interview.md`
- Artifact content specs: `references/artifact-specs.md`
- CI workflow templates: `references/ci-templates.md`
- Stack conventions: `references/stacks/`
```

---

## Step 2 — Create `skills/greenfield/scripts/detect-stack.sh`

This script inspects the current directory and outputs a JSON object.

Content to write:

```bash
#!/bin/bash
set -e

# detect-stack.sh
# Detects project stack from files in the current directory.
# Outputs JSON to stdout. Status messages to stderr.

echo "Detecting project stack..." >&2

STACK="unknown"
FRAMEWORK="unknown"
PKG_MANAGER="npm"
FORMATTER="prettier"
TEST_RUNNER="none"
LANG="unknown"
HAS_TYPESCRIPT="false"

# --- Node.js detection ---
if [ -f "package.json" ]; then
  LANG="javascript"

  # Package manager
  [ -f "bun.lockb" ] && PKG_MANAGER="bun"
  [ -f "pnpm-lock.yaml" ] && PKG_MANAGER="pnpm"
  [ -f "yarn.lock" ] && PKG_MANAGER="yarn"

  # TypeScript
  [ -f "tsconfig.json" ] && HAS_TYPESCRIPT="true" && LANG="typescript"

  # Formatter
  if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
    FORMATTER="biome"
  elif ls .prettierrc* prettier.config.* 2>/dev/null | grep -q .; then
    FORMATTER="prettier"
  fi

  # Framework
  if grep -q '"next"' package.json 2>/dev/null; then
    FRAMEWORK="nextjs"
    STACK="nextjs"
  elif grep -q '"react"' package.json 2>/dev/null; then
    FRAMEWORK="react"
    STACK="react"
  elif grep -qE '"express"|"fastify"|"hono"' package.json 2>/dev/null; then
    FRAMEWORK="node-api"
    STACK="typescript-node"
  else
    FRAMEWORK="node"
    STACK="typescript-node"
  fi

  # Test runner
  grep -q '"vitest"' package.json 2>/dev/null && TEST_RUNNER="vitest"
  grep -q '"jest"' package.json 2>/dev/null && TEST_RUNNER="jest"
  grep -q '"mocha"' package.json 2>/dev/null && TEST_RUNNER="mocha"

# --- Python detection ---
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  LANG="python"
  STACK="python"
  PKG_MANAGER="pip"
  FORMATTER="ruff"
  TEST_RUNNER="pytest"

  # Sub-framework
  if grep -qE "fastapi|django|flask" requirements.txt pyproject.toml 2>/dev/null; then
    grep -qi "fastapi" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="fastapi"
    grep -qi "django" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="django"
    grep -qi "flask" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="flask"
  fi

# --- Go detection ---
elif [ -f "go.mod" ]; then
  LANG="go"
  STACK="go"
  PKG_MANAGER="go"
  FORMATTER="gofmt"
  TEST_RUNNER="go-test"
  FRAMEWORK="go"

# --- Rust detection ---
elif [ -f "Cargo.toml" ]; then
  LANG="rust"
  STACK="rust"
  PKG_MANAGER="cargo"
  FORMATTER="rustfmt"
  TEST_RUNNER="cargo-test"
  FRAMEWORK="rust"

# --- .NET detection ---
elif ls *.csproj 2>/dev/null | grep -q .; then
  LANG="csharp"
  STACK="dotnet"
  PKG_MANAGER="dotnet"
  FORMATTER="dotnet-format"
  TEST_RUNNER="dotnet-test"
  FRAMEWORK="dotnet"
fi

echo "Detected: $STACK ($LANG) with $PKG_MANAGER" >&2

# Output JSON
cat <<EOF
{
  "stack": "$STACK",
  "framework": "$FRAMEWORK",
  "lang": "$LANG",
  "pkg_manager": "$PKG_MANAGER",
  "formatter": "$FORMATTER",
  "test_runner": "$TEST_RUNNER",
  "has_typescript": $HAS_TYPESCRIPT
}
EOF
```

---

## Step 3 — Create `skills/greenfield/scripts/generate-settings.sh`

Writes `.claude/settings.json` and `.claude/settings.local.json`.

Content to write:

```bash
#!/bin/bash
set -e

# generate-settings.sh
# Writes .claude/settings.json and .claude/settings.local.json
# Reads config from environment variables.

echo "Generating settings files..." >&2

mkdir -p .claude

PROJECT_DIR="${PROJECT_DIR:-.}"
AGENT_TEAMS="${AGENT_TEAMS:-false}"
PKG_MANAGER="${PKG_MANAGER:-npm}"
LINT_CMD="${LINT_CMD:-npm run lint}"
TEST_CMD="${TEST_CMD:-npm test}"

# --- settings.json ---

ENV_BLOCK=""
if [ "$AGENT_TEAMS" = "true" ]; then
  ENV_BLOCK='"env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },'
fi

cat > .claude/settings.json <<SETTINGS
{
  $ENV_BLOCK
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/guard.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/format.sh\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/stop-quality-gate.sh\""
          },
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/task-summary.sh\""
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/stop-quality-gate.sh\""
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/save-context.sh\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"\$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh\""
          }
        ]
      }
    ]
  }
}
SETTINGS

echo "Wrote .claude/settings.json" >&2

# --- settings.local.json ---
# Stack-specific permission allows

case "$PKG_MANAGER" in
  npm|pnpm|yarn|bun)
    PERMS="\"Bash($PKG_MANAGER install:*)\",
      \"Bash($PKG_MANAGER run *:*)\",
      \"Bash(node:*)\",
      \"Bash(npx tsc:*)\","
    ;;
  pip)
    PERMS="\"Bash(pip install:*)\",
      \"Bash(python:*)\",
      \"Bash(pytest:*)\",
      \"Bash(ruff:*)\","
    ;;
  go)
    PERMS="\"Bash(go build:*)\",
      \"Bash(go test:*)\",
      \"Bash(go run:*)\",
      \"Bash(go mod:*)\",
      \"Bash(go vet:*)\","
    ;;
  cargo)
    PERMS="\"Bash(cargo:*)\","
    ;;
  *)
    PERMS=""
    ;;
esac

cat > .claude/settings.local.json <<LOCAL
{
  "permissions": {
    "allow": [
      $PERMS
      "Bash(git add:*)",
      "Bash(git commit:*)"
    ]
  }
}
LOCAL

echo "Wrote .claude/settings.local.json" >&2
echo '{"status":"ok","files":[".claude/settings.json",".claude/settings.local.json"]}'
```

---

## Step 4 — Create `skills/greenfield/scripts/generate-rules.sh`

Writes `.claude/rules/*.md` files based on the detected stack.

Content to write:

```bash
#!/bin/bash
set -e

# generate-rules.sh
# Writes .claude/rules/ files appropriate for the detected stack.

echo "Generating rules files..." >&2

mkdir -p .claude/rules

STACK="${STACK:-typescript-node}"
GENERATED_FILES=()

# --- general.md (always) ---
cat > .claude/rules/general.md <<'RULE'
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
cat > .claude/rules/security.md <<'RULE'
# Security Rules

- Never hardcode secrets, API keys, or credentials — use environment variables
- Validate all external input at the boundary
- Use parameterized queries or ORM — never interpolate user input into SQL
- Sanitize output that reaches HTML/templates
- Never log sensitive data (passwords, tokens, PII)
RULE
GENERATED_FILES+=(".claude/rules/security.md")

# --- testing.md (always) ---
cat > .claude/rules/testing.md <<'RULE'
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
    cat > .claude/rules/frontend.md <<'RULE'
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

    cat > .claude/rules/api.md <<'RULE'
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
    cat > .claude/rules/api.md <<'RULE'
---
paths:
  - "src/api/**"
  - "src/routes/**"
  - "src/server/**"
---

# API Rules

- Validate all input — use zod or equivalent
- Return consistent error shapes with appropriate HTTP status codes
- Use parameterized queries — never raw string interpolation for SQL
- Include rate limiting on public-facing endpoints
RULE
    GENERATED_FILES+=(".claude/rules/api.md")
    ;;
esac

echo "Wrote ${#GENERATED_FILES[@]} rules files" >&2

# Output JSON list of created files
FILES_JSON=$(printf '"%s",' "${GENERATED_FILES[@]}" | sed 's/,$//')
echo "{\"status\":\"ok\",\"files\":[$FILES_JSON]}"
```

---

## Step 5 — Create `skills/greenfield/scripts/generate-hooks.sh`

Writes all `.claude/hooks/*.sh` files and makes them executable.

Content to write:

```bash
#!/bin/bash
set -e

# generate-hooks.sh
# Writes all .claude/hooks/*.sh files for the detected stack.

echo "Generating hook scripts..." >&2

mkdir -p .claude/hooks

LINT_CMD="${LINT_CMD:-npm run lint}"
TEST_CMD="${TEST_CMD:-npm test -- --passWithNoTests}"
FORMATTER="${FORMATTER:-prettier}"
STACK="${STACK:-typescript-node}"

# --- guard.sh ---
cat > .claude/hooks/guard.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && echo '{"decision":"approve"}' && exit 0
if echo "$CMD" | grep -qEi '(rm -rf /|DROP TABLE|DROP DATABASE|DELETE FROM .* WHERE 1=1|push\s+.*--force|> /dev/sd|mkfs|dd if=)'; then
  echo '{"decision":"block","reason":"Blocked: destructive command detected."}'
  exit 0
fi
if echo "$CMD" | grep -qEi '(curl.*(-d|--data).*(_KEY|_SECRET|_TOKEN|PASSWORD)|echo.*(_KEY|_SECRET|_TOKEN))'; then
  echo '{"decision":"block","reason":"Blocked: potential secret exposure. Use environment variables."}'
  exit 0
fi
echo '{"decision":"approve"}'
HOOK

# --- format.sh ---
cat > .claude/hooks/format.sh <<HOOK
#!/usr/bin/env bash
INPUT=\$(cat)
FILE=\$(echo "\$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "\$FILE" ]] && exit 0
[[ ! -f "\$FILE" ]] && exit 0
HOOK

case "$FORMATTER" in
  biome)
    cat >> .claude/hooks/format.sh <<'HOOK'
npx @biomejs/biome format --write "$FILE" 2>/dev/null || true
HOOK
    ;;
  ruff)
    cat >> .claude/hooks/format.sh <<'HOOK'
ruff format "$FILE" 2>/dev/null || black "$FILE" 2>/dev/null || true
HOOK
    ;;
  gofmt)
    cat >> .claude/hooks/format.sh <<'HOOK'
gofmt -w "$FILE" 2>/dev/null || true
HOOK
    ;;
  rustfmt)
    cat >> .claude/hooks/format.sh <<'HOOK'
rustfmt "$FILE" 2>/dev/null || true
HOOK
    ;;
  *)
    cat >> .claude/hooks/format.sh <<'HOOK'
npx prettier --write "$FILE" 2>/dev/null || true
HOOK
    ;;
esac

# --- stop-quality-gate.sh ---
cat > .claude/hooks/stop-quality-gate.sh <<HOOK
#!/usr/bin/env bash
set -euo pipefail
INPUT=\$(cat)
STOP_HOOK_ACTIVE=\$(echo "\$INPUT" | jq -r '.stop_hook_active // false')
[[ "\$STOP_HOOK_ACTIVE" == "true" ]] && exit 0
AGENT_TYPE=\$(echo "\$INPUT" | jq -r '.agent_type // "main"')
[[ "\$AGENT_TYPE" == "hook-agent" ]] && exit 0
ERRORS=""
cd "\$CLAUDE_PROJECT_DIR"
CHANGED=\$(git diff --name-only HEAD 2>/dev/null || echo "")
[[ -z "\$CHANGED" ]] && exit 0
if ! output=\$(${LINT_CMD} 2>&1); then
  ERRORS+="\n## Lint Failed\n\`\`\`\n\${output}\n\`\`\`\n"
fi
if ! output=\$(${TEST_CMD} 2>&1); then
  ERRORS+="\n## Tests Failed\n\`\`\`\n\${output}\n\`\`\`\n"
fi
if [[ -n "\$ERRORS" ]]; then
  printf "Quality gate failed — fix before completing:\n%b" "\$ERRORS" >&2
  exit 2
fi
exit 0
HOOK

# --- task-summary.sh ---
cat > .claude/hooks/task-summary.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
{
  echo "# Session Complete — $TIMESTAMP"
  echo "Branch: $BRANCH"
  echo ""
  echo "## Files Changed"
  git diff --stat HEAD 2>/dev/null || git status --short
  echo ""
  echo "## Recent Commits"
  git log --oneline -5 2>/dev/null || echo "(no commits)"
} > "$CLAUDE_PROJECT_DIR/.claude/logs/session-$TIMESTAMP.md" 2>/dev/null
exit 0
HOOK

# --- save-context.sh ---
cat > .claude/hooks/save-context.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/scratch"
SCRATCH="$CLAUDE_PROJECT_DIR/.claude/scratch/wip-$(date +%Y%m%d-%H%M%S).md"
INPUT=$(cat)
CUSTOM=$(echo "$INPUT" | jq -r '.custom_instructions // empty')
cat > "$SCRATCH" <<EOF
# WIP Snapshot — $(date)
${CUSTOM}
## Git Status
$(cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "unavailable")
EOF
echo "Context saved to $SCRATCH" >&2
exit 0
HOOK

# --- session-start.sh ---
cat > .claude/hooks/session-start.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
if [[ "$AGENT_TYPE" == "subagent" ]] || [[ "$AGENT_TYPE" == "teammate" ]]; then
  exit 0
fi
echo "## Git State"
cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "(not a git repo)"
echo ""
echo "## Branch"
git branch --show-current 2>/dev/null || echo "(unknown)"
echo ""
echo "## Recent Commits"
git log --oneline -5 2>/dev/null || echo "(no commits yet)"
exit 0
HOOK

# Make all hooks executable
chmod +x .claude/hooks/*.sh

echo "Wrote and chmod +x all hook scripts" >&2
echo '{"status":"ok","files":["guard.sh","format.sh","stop-quality-gate.sh","task-summary.sh","save-context.sh","session-start.sh"]}'
```

---

## Step 6 — Create `skills/greenfield/scripts/generate-claude-md.sh`

Writes `CLAUDE.md` at the project root.

Content to write:

```bash
#!/bin/bash
set -e

# generate-claude-md.sh
# Writes CLAUDE.md at the project root using interview answers.

echo "Generating CLAUDE.md..." >&2

PROJECT_NAME="${PROJECT_NAME:-My Project}"
PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION:-A new project.}"
STACK="${STACK:-typescript-node}"
INSTALL_CMD="${INSTALL_CMD:-npm install}"
DEV_CMD="${DEV_CMD:-npm run dev}"
BUILD_CMD="${BUILD_CMD:-npm run build}"
TEST_CMD="${TEST_CMD:-npm test}"
LINT_CMD="${LINT_CMD:-npm run lint}"
COMMIT_STYLE="${COMMIT_STYLE:-conventional}"

cat > CLAUDE.md <<CLAUDEMD
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

echo "Wrote CLAUDE.md" >&2
echo '{"status":"ok","files":["CLAUDE.md"]}'
```

---

## Step 7 — Create `skills/greenfield/scripts/generate-gitignore.sh`

Appends Claude Code entries to `.gitignore`.

Content to write:

```bash
#!/bin/bash
set -e

# generate-gitignore.sh
# Appends Claude Code personal/generated file entries to .gitignore.

echo "Updating .gitignore..." >&2

ENTRIES=(
  "CLAUDE.local.md"
  ".claude/settings.local.json"
  ".claude/logs/"
  ".claude/scratch/"
  ".claude/tasks/"
  ".claude/specs/"
)

# Create .gitignore if it doesn't exist
touch .gitignore

# Only append entries that aren't already present
ADDED=0
for ENTRY in "${ENTRIES[@]}"; do
  if ! grep -qF "$ENTRY" .gitignore 2>/dev/null; then
    echo "$ENTRY" >> .gitignore
    ADDED=$((ADDED + 1))
  fi
done

# Add section header if we added anything
if [ "$ADDED" -gt 0 ]; then
  # Prepend header before the entries we added
  # (simple approach: just ensure comment exists)
  if ! grep -q "Claude Code" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Claude Code — personal and generated files" >> .gitignore
    for ENTRY in "${ENTRIES[@]}"; do
      grep -qF "$ENTRY" .gitignore || echo "$ENTRY" >> .gitignore
    done
  fi
fi

echo "Updated .gitignore (added $ADDED entries)" >&2
echo "{\"status\":\"ok\",\"entries_added\":$ADDED}"
```

---

## Step 8 — Create `skills/greenfield/references/interview.md`

Copy the content from the previously generated `greenfield/references/interview.md` file.
This file contains the full developer interview question set and conditional logic.
It is read by SKILL.md during Step 3 of the skill execution.

---

## Step 9 — Create `skills/greenfield/references/artifact-specs.md`

Copy the content from the previously generated `greenfield/references/artifact-specs.md` file.
This file contains the exact content specifications for every generated artifact.
It is used as a reference when the scripts need guidance on what to write.

---

## Step 10 — Create `skills/greenfield/references/ci-templates.md`

Copy the content from the previously generated `greenfield/references/ci-templates.md` file.
This file contains GitHub Actions workflow templates for each stack.
It is read during Step 7 (CI/CD scaffold) of the skill execution.

---

## Step 11 — Create `skills/greenfield/references/stacks/nextjs-react.md`

Copy the content from the previously generated `greenfield/stacks/nextjs-react.md` file.

---

## Step 12 — Create `skills/greenfield/references/stacks/typescript-node.md`

Copy the content from the previously generated `greenfield/stacks/typescript-node.md` file.

---

## Step 13 — Create `skills/greenfield/references/stacks/python.md`

Copy the content from the previously generated `greenfield/stacks/python.md` file.

---

## Step 14 — Create `skills/greenfield/references/stacks/go.md`

Copy the content from the previously generated `greenfield/stacks/go.md` file.

---

## Step 15 — Package the Skill

After all files are created, run:

```bash
cd skills
zip -r greenfield.zip greenfield/
```

This produces `skills/greenfield.zip` for distribution.

---

## Step 16 — Verify Structure

Run this to confirm everything is in place:

```bash
find skills/greenfield -type f | sort
```

Expected output:
```
skills/greenfield/SKILL.md
skills/greenfield/references/artifact-specs.md
skills/greenfield/references/ci-templates.md
skills/greenfield/references/interview.md
skills/greenfield/references/stacks/go.md
skills/greenfield/references/stacks/nextjs-react.md
skills/greenfield/references/stacks/python.md
skills/greenfield/references/stacks/typescript-node.md
skills/greenfield/scripts/detect-stack.sh
skills/greenfield/scripts/generate-claude-md.sh
skills/greenfield/scripts/generate-gitignore.sh
skills/greenfield/scripts/generate-hooks.sh
skills/greenfield/scripts/generate-rules.sh
skills/greenfield/scripts/generate-settings.sh
```

And verify scripts are executable:
```bash
ls -la skills/greenfield/scripts/
```

---

## Notes for CC

- The `references/` files in Steps 8–14 already exist as downloads from the previous session. CC should copy their content verbatim rather than regenerating.
- The scripts in Steps 2–7 are new and should be created exactly as written above.
- All `.sh` files must be executable (`chmod +x`) after creation.
- The SKILL.md in Step 1 is a condensed orchestrator — it references scripts and reference files rather than containing all content inline.
