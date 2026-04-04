# Brownfield Skill — Implementation Plan

This document tells Claude Code exactly what files to create and where.
Follow each step in order. Create files exactly as written.

---

## Overview

The brownfield skill configures Claude Code for an **existing** codebase by
discovering what's already there — conventions, architecture, testing patterns,
git workflow — then generating tailored `.claude/` configuration from those findings.

Unlike greenfield (which defines conventions), brownfield **detects** them.

**What this skill generates:**
- `CLAUDE.md` at the project root
- `.claude/rules/*.md` — derived from actual discovered conventions
- `.claude/hooks/*.sh` — tailored to detected tools and test commands
- `.claude/settings.json` + `.claude/settings.local.json`
- `.gitignore` additions

Does NOT install commands or agents — the `workflow` skill handles that.

---

## Directory Structure to Create

```
skills/
└── brownfield/
    ├── SKILL.md
    ├── scripts/
    │   ├── analyze-repo.sh              ← stack, pkg manager, lint/test commands
    │   ├── analyze-conventions.sh       ← naming, imports, formatting patterns
    │   ├── analyze-git.sh               ← commit style, branch naming, CI
    │   ├── analyze-tests.sh             ← test framework, file locations, utilities
    │   ├── generate-rules.sh            ← writes .claude/rules/ from analysis
    │   ├── generate-hooks.sh            ← writes .claude/hooks/ from analysis
    │   ├── generate-settings.sh         ← writes settings.json + settings.local.json
    │   ├── generate-claude-md.sh        ← writes CLAUDE.md
    │   └── generate-gitignore.sh        ← appends Claude entries to .gitignore
    └── references/
        ├── rules-templates.md           ← content guidelines for each rules file
        └── hook-detection.md            ← which hooks to recommend based on findings
```

---

## Step 1 — Create `skills/brownfield/SKILL.md`

```markdown
---
name: brownfield
description: >
  Configure Claude Code for an existing codebase by discovering its conventions,
  architecture, testing patterns, and git workflow — then generating tailored
  CLAUDE.md, rules, hooks, and settings. Use when a developer says "set up
  Claude Code for this project", "onboard Claude to this repo", "/brownfield",
  "analyze this codebase for Claude", or opens an existing project with no
  .claude/ directory. Run the workflow skill after this to install development
  commands and agents.
---

# Brownfield Setup

Configures Claude Code for an existing codebase by discovering what's already
there. Conventions are detected from the actual project — not assumed from
templates.

Run the `workflow` skill after this to install commands and agents:
```
npx skills add squirrelsoft-dev/agent-skills@workflow
```

---

## Step 1 — Preflight

Check for existing setup and available execution mode:

```bash
ls .claude/ 2>/dev/null && echo "EXISTS" || echo "FRESH"
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-disabled}"
claude --version 2>/dev/null || echo "unknown"
```

If `.claude/` already exists, ask the developer:
> "A `.claude/` directory already exists. Running this will overwrite it.
> Continue, or run the greenfield skill instead for a fresh setup?"

Wait for confirmation before proceeding.

---

## Step 2 — Parallel Analysis

Run all four analysis scripts. Use subagents in parallel if available,
otherwise run sequentially. All scripts are read-only — no files are
written in this phase.

```bash
bash scripts/analyze-repo.sh        > /tmp/bf-repo.json
bash scripts/analyze-conventions.sh > /tmp/bf-conventions.json
bash scripts/analyze-git.sh         > /tmp/bf-git.json
bash scripts/analyze-tests.sh       > /tmp/bf-tests.json
```

---

## Step 3 — Human Review Checkpoint

Synthesize findings from the four JSON outputs and present this summary.
Do NOT write any files yet.

```
## Brownfield Analysis — [Project Name]

### Stack & Runtime
[language, framework, versions, package manager]

### Conventions Detected
[naming, imports, formatting — with real file examples from the codebase]

### Testing
[framework, file locations, exact run command]

### Git & Collaboration
[commit style with 3 real examples from git log, branch pattern]

### ⚠️ Conflicts & Ambiguities
[list any competing conventions that need a human decision]
[e.g. "Files in /legacy use snake_case, files in /src use camelCase — which is current?"]

### Tech Debt Signals
[TODO/FIXME density, files untouched 12+ months, deprecated patterns]
```

Then ask these questions in the same message:

1. Does this match your understanding? Correct anything that's wrong.
2. For any conflicts listed above — which convention is the current standard?
3. Enable agent teams? (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — yes / no
4. Commit style going forward? — detected style / conventional commits / free-form
5. Scaffold GitHub Actions CI if none detected? — yes / no

Also detect and report quality tools:
```bash
command -v gitleaks &>/dev/null && echo "gitleaks: installed" || echo "gitleaks: missing"
command -v semgrep  &>/dev/null && echo "semgrep: installed"  || echo "semgrep: missing"
command -v gh       &>/dev/null && echo "gh CLI: installed"   || echo "gh CLI: missing"
```

For any missing tools, note what they do and recommend installing before `/workflow`.

**Wait for developer response before proceeding to Step 4.**

---

## Step 4 — Generate All Artifacts

After the developer confirms findings and answers questions, generate everything.
Use subagents in parallel if available, otherwise sequential.

Pass confirmed answers as environment variables to each script.

### 4a — Rules
```bash
STACK="[detected]" \
CONVENTIONS_JSON="/tmp/bf-conventions.json" \
TESTS_JSON="/tmp/bf-tests.json" \
REPO_JSON="/tmp/bf-repo.json" \
bash scripts/generate-rules.sh
```

### 4b — Hooks
```bash
LINT_CMD="[from bf-repo.json]" \
TEST_CMD="[from bf-repo.json]" \
FORMATTER="[from bf-repo.json]" \
AGENT_TEAMS="[from developer answer]" \
bash scripts/generate-hooks.sh
```

### 4c — Settings
```bash
PKG_MANAGER="[from bf-repo.json]" \
AGENT_TEAMS="[from developer answer]" \
LINT_CMD="[from bf-repo.json]" \
TEST_CMD="[from bf-repo.json]" \
bash scripts/generate-settings.sh
```

### 4d — CLAUDE.md
```bash
REPO_JSON="/tmp/bf-repo.json" \
GIT_JSON="/tmp/bf-git.json" \
PROJECT_NAME="[detected or asked]" \
COMMIT_STYLE="[from developer answer]" \
bash scripts/generate-claude-md.sh
```

### 4e — .gitignore
```bash
bash scripts/generate-gitignore.sh
```

Content guidelines for rules: `references/rules-templates.md`
Hook recommendations: `references/hook-detection.md`

---

## Step 5 — Commit

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code configuration for brownfield onboarding"
```

If conventional commits were detected or chosen:
```bash
git commit -m "chore(claude): add brownfield Claude Code configuration"
```

---

## Step 6 — Completion

```
✅ Brownfield Setup Complete — [Project Name]

Generated:
- CLAUDE.md
- .claude/settings.json        (agent teams: yes/no)
- .claude/settings.local.json
- .claude/rules/               [list each file]
- .claude/hooks/               [list each script]

Key conventions captured:
- [most important naming rule with example]
- [commit format with example]
- [test location and run command]

Next steps:
1. npx skills add squirrelsoft-dev/agent-skills@workflow
2. Launch Claude Code
3. Run /workflow to install commands and agents
4. Restart Claude Code
```

---

## Reference Files

- Rules content guidelines: `references/rules-templates.md`
- Hook recommendation logic: `references/hook-detection.md`
```

---

## Step 2 — Create `skills/brownfield/scripts/analyze-repo.sh`

Detects stack, framework, package manager, formatter, and available commands.
Outputs JSON to stdout. Status messages to stderr.

```bash
#!/bin/bash
set -e
# analyze-repo.sh
# Detects project stack, framework, package manager, formatter, and commands.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing repository structure..." >&2

STACK="unknown"
FRAMEWORK="unknown"
PKG_MANAGER="unknown"
FORMATTER="none"
LANG="unknown"
HAS_TYPESCRIPT="false"
IS_MONOREPO="false"
LINT_CMD=""
TEST_CMD=""
BUILD_CMD=""
DEV_CMD=""
INSTALL_CMD=""
HAS_HUSKY="false"
HAS_LEFTHOOK="false"

# Monorepo
[ -f "turbo.json" ] && IS_MONOREPO="true"
[ -f "pnpm-workspace.yaml" ] && IS_MONOREPO="true"
[ -f "lerna.json" ] && IS_MONOREPO="true"

# Pre-commit hooks
[ -d ".husky" ] && HAS_HUSKY="true"
{ [ -f ".lefthook.yml" ] || [ -f "lefthook.yml" ]; } && HAS_LEFTHOOK="true"

if [ -f "package.json" ]; then
  LANG="javascript"
  [ -f "bun.lockb" ]      && PKG_MANAGER="bun"
  [ -f "pnpm-lock.yaml" ] && PKG_MANAGER="pnpm"
  [ -f "yarn.lock" ]      && PKG_MANAGER="yarn"
  [ "$PKG_MANAGER" = "unknown" ] && PKG_MANAGER="npm"
  [ -f "tsconfig.json" ] && HAS_TYPESCRIPT="true" && LANG="typescript"

  [ -f "biome.json" ] || [ -f "biome.jsonc" ] && FORMATTER="biome" || true
  ls .prettierrc* prettier.config.* 2>/dev/null | grep -q . && FORMATTER="prettier" || true

  grep -q '"next"' package.json 2>/dev/null    && FRAMEWORK="nextjs"    && STACK="nextjs"
  grep -q '"react"' package.json 2>/dev/null   && FRAMEWORK="react"     && STACK="react"
  grep -qE '"express"|"fastify"|"hono"' package.json 2>/dev/null && FRAMEWORK="node-api" && STACK="typescript-node"
  [ "$STACK" = "unknown" ] && FRAMEWORK="node" && STACK="typescript-node"

  # Extract scripts from package.json
  has_script() { node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts['$1']?0:1)" 2>/dev/null; }
  has_script "lint"  && LINT_CMD="$PKG_MANAGER run lint"
  has_script "test"  && TEST_CMD="$PKG_MANAGER test"
  has_script "build" && BUILD_CMD="$PKG_MANAGER run build"
  has_script "dev"   && DEV_CMD="$PKG_MANAGER run dev"
  INSTALL_CMD="$PKG_MANAGER install"

  # Add passWithNoTests flag for jest/vitest
  grep -qE '"vitest"|"jest"' package.json 2>/dev/null && TEST_CMD="$TEST_CMD -- --passWithNoTests"

elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  LANG="python"; STACK="python"; FORMATTER="ruff"
  PKG_MANAGER="pip"; INSTALL_CMD="pip install -r requirements.txt"
  LINT_CMD="ruff check ."; TEST_CMD="pytest --tb=short -q"
  grep -q "poetry" pyproject.toml 2>/dev/null && PKG_MANAGER="poetry" && INSTALL_CMD="poetry install"
  grep -q "\[tool.uv\]" pyproject.toml 2>/dev/null && PKG_MANAGER="uv" && INSTALL_CMD="uv sync"
  grep -qi "fastapi" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="fastapi"
  grep -qi "django"  requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="django"
  grep -qi "flask"   requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="flask"

elif [ -f "go.mod" ]; then
  LANG="go"; STACK="go"; PKG_MANAGER="go"; FRAMEWORK="go"; FORMATTER="gofmt"
  LINT_CMD="go vet ./..."; TEST_CMD="go test ./..."
  BUILD_CMD="go build ./..."; INSTALL_CMD="go mod download"

elif [ -f "Cargo.toml" ]; then
  LANG="rust"; STACK="rust"; PKG_MANAGER="cargo"; FRAMEWORK="rust"; FORMATTER="rustfmt"
  LINT_CMD="cargo clippy"; TEST_CMD="cargo test"
  BUILD_CMD="cargo build --release"; INSTALL_CMD="cargo build"

elif ls *.csproj 2>/dev/null | grep -q .; then
  LANG="csharp"; STACK="dotnet"; PKG_MANAGER="dotnet"; FRAMEWORK="dotnet"
  FORMATTER="dotnet-format"; LINT_CMD="dotnet build"
  TEST_CMD="dotnet test"; BUILD_CMD="dotnet build --configuration Release"
  INSTALL_CMD="dotnet restore"
fi

echo "Detected: $STACK ($LANG) with $PKG_MANAGER" >&2

cat <<EOF
{
  "stack": "$STACK",
  "framework": "$FRAMEWORK",
  "lang": "$LANG",
  "pkg_manager": "$PKG_MANAGER",
  "formatter": "$FORMATTER",
  "has_typescript": $HAS_TYPESCRIPT,
  "is_monorepo": $IS_MONOREPO,
  "has_husky": $HAS_HUSKY,
  "has_lefthook": $HAS_LEFTHOOK,
  "commands": {
    "lint": "$LINT_CMD",
    "test": "$TEST_CMD",
    "build": "$BUILD_CMD",
    "dev": "$DEV_CMD",
    "install": "$INSTALL_CMD"
  }
}
EOF
```

---

## Step 3 — Create `skills/brownfield/scripts/analyze-conventions.sh`

Samples source files to detect naming conventions, import style, and formatting.
Outputs JSON to stdout.

```bash
#!/bin/bash
set -e
# analyze-conventions.sh
# Samples source files to detect naming and formatting conventions.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing code conventions..." >&2

FILE_NAMING="unknown"
IMPORT_STYLE="unknown"
QUOTE_STYLE="unknown"
SEMICOLONS="unknown"
PATH_ALIASES=""
ORG_PATTERN="unknown"

# Detect indent from editorconfig
INDENT_STYLE="spaces"
if [ -f ".editorconfig" ]; then
  grep -q "indent_style = tab" .editorconfig 2>/dev/null && INDENT_STYLE="tabs"
fi

# Sample TS/JS source files
SAMPLE_FILES=$(find src app lib -maxdepth 4 \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null | grep -v node_modules | head -20)

if [ -n "$SAMPLE_FILES" ]; then
  SINGLE=$(echo "$SAMPLE_FILES" | xargs grep -hc "'" 2>/dev/null | awk '{s+=$1}END{print s+0}')
  DOUBLE=$(echo "$SAMPLE_FILES" | xargs grep -hc '"' 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "$SINGLE" -gt "$DOUBLE" ] && QUOTE_STYLE="single" || QUOTE_STYLE="double"

  SEMI=$(echo "$SAMPLE_FILES" | xargs grep -hcE ';$' 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "$SEMI" -gt 20 ] && SEMICOLONS="yes" || SEMICOLONS="no"

  ABS=$(echo "$SAMPLE_FILES" | xargs grep -hcE "^import.*from '@" 2>/dev/null | awk '{s+=$1}END{print s+0}')
  REL=$(echo "$SAMPLE_FILES" | xargs grep -hcE "^import.*from '\.\." 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "$ABS" -gt "$REL" ] && IMPORT_STYLE="absolute" || IMPORT_STYLE="relative"
fi

# Path aliases from tsconfig
if [ -f "tsconfig.json" ] && command -v node &>/dev/null; then
  PATH_ALIASES=$(node -e "
    try {
      const c = require('./tsconfig.json');
      const paths = c.compilerOptions && c.compilerOptions.paths;
      if (paths) console.log(Object.keys(paths).join(', '));
    } catch(e) {}
  " 2>/dev/null || echo "")
fi

# File naming pattern from actual filenames
KEBAB=$(find src app lib -maxdepth 4 \( -name "*-*.ts" -o -name "*-*.tsx" \) 2>/dev/null | wc -l)
PASCAL=$(find src app lib -maxdepth 4 -name "[A-Z]*.tsx" 2>/dev/null | wc -l)
if [ "$PASCAL" -gt "$KEBAB" ]; then FILE_NAMING="PascalCase"
elif [ "$KEBAB" -gt 0 ]; then FILE_NAMING="kebab-case"
fi

# Org structure
if [ -d "src/components" ] && [ -d "src/services" ]; then ORG_PATTERN="layer-based"
elif [ -d "src/features" ] || [ -d "src/modules" ]; then ORG_PATTERN="feature-based"
fi

echo "Conventions analyzed" >&2

cat <<EOF
{
  "file_naming": "$FILE_NAMING",
  "import_style": "$IMPORT_STYLE",
  "indent_style": "$INDENT_STYLE",
  "quote_style": "$QUOTE_STYLE",
  "semicolons": "$SEMICOLONS",
  "path_aliases": "$PATH_ALIASES",
  "org_pattern": "$ORG_PATTERN"
}
EOF
```

---

## Step 4 — Create `skills/brownfield/scripts/analyze-git.sh`

Reads git log and branches to detect commit style and CI setup.
Outputs JSON to stdout.

```bash
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
```

---

## Step 5 — Create `skills/brownfield/scripts/analyze-tests.sh`

Detects test framework, file locations, and available test utilities.
Outputs JSON to stdout.

```bash
#!/bin/bash
set -e
# analyze-tests.sh
# Detects test framework, file locations, and utilities.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing test setup..." >&2

FRAMEWORK="none"
FILE_LOCATION="unknown"
FILE_PATTERN="unknown"
HAS_FACTORIES="false"
HAS_FIXTURES="false"
HAS_MSW="false"
COVERAGE_TOOL="none"

# Framework detection
if [ -f "package.json" ]; then
  grep -q '"vitest"' package.json 2>/dev/null  && FRAMEWORK="vitest"
  grep -q '"jest"' package.json 2>/dev/null    && [ "$FRAMEWORK" = "none" ] && FRAMEWORK="jest"
  grep -q '"mocha"' package.json 2>/dev/null   && [ "$FRAMEWORK" = "none" ] && FRAMEWORK="mocha"
  grep -q '"msw"' package.json 2>/dev/null     && HAS_MSW="true"
  grep -q '"@vitest/coverage' package.json 2>/dev/null && COVERAGE_TOOL="v8"
  grep -q '"istanbul"' package.json 2>/dev/null        && COVERAGE_TOOL="istanbul"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  FRAMEWORK="pytest"
elif [ -f "go.mod" ]; then
  FRAMEWORK="go-test"
elif [ -f "Cargo.toml" ]; then
  FRAMEWORK="cargo-test"
fi

# Test file locations
COLOCATED=$(find src app lib -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" 2>/dev/null | head -5 | wc -l)
SEPARATE=$(find tests test __tests__ -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" 2>/dev/null | head -5 | wc -l)

if [ "$COLOCATED" -gt "$SEPARATE" ]; then
  FILE_LOCATION="co-located"
  FILE_PATTERN="*.test.ts alongside source"
elif [ "$SEPARATE" -gt 0 ]; then
  FILE_LOCATION="separate-directory"
  [ -d "tests" ] && FILE_PATTERN="tests/**/*.test.*"
  [ -d "__tests__" ] && FILE_PATTERN="__tests__/**"
fi

# Factory/fixture detection
find . -name "factory*" -o -name "*factory*" -o -name "factories*" 2>/dev/null | grep -v node_modules | grep -q . && HAS_FACTORIES="true"
find . -name "fixture*" -o -name "fixtures*" 2>/dev/null | grep -v node_modules | grep -q . && HAS_FIXTURES="true"

echo "Test analysis complete" >&2

cat <<EOF
{
  "framework": "$FRAMEWORK",
  "file_location": "$FILE_LOCATION",
  "file_pattern": "$FILE_PATTERN",
  "has_factories": $HAS_FACTORIES,
  "has_fixtures": $HAS_FIXTURES,
  "has_msw": $HAS_MSW,
  "coverage_tool": "$COVERAGE_TOOL"
}
EOF
```

---

## Step 6 — Create `skills/brownfield/scripts/generate-rules.sh`

Writes `.claude/rules/*.md` files using discovered conventions.
Content should use REAL examples from the codebase — not generic placeholders.

```bash
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
```

---

## Step 7 — Create `skills/brownfield/scripts/generate-hooks.sh`

Writes all `.claude/hooks/*.sh` files using discovered tool commands.
Same hook set as greenfield — but commands are detected, not assumed.

```bash
#!/bin/bash
set -e
# generate-hooks.sh
# Writes .claude/hooks/ scripts tailored to detected tools.
# Commands come from analysis JSON — not hardcoded defaults.

echo "Generating hook scripts..." >&2

mkdir -p .claude/hooks

LINT_CMD="${LINT_CMD:-echo 'no lint configured'}"
TEST_CMD="${TEST_CMD:-echo 'no test configured'}"
FORMATTER="${FORMATTER:-prettier}"
AGENT_TEAMS="${AGENT_TEAMS:-false}"

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

# --- format.sh (formatter-specific) ---
cat > .claude/hooks/format.sh <<HOOK
#!/usr/bin/env bash
INPUT=\$(cat)
FILE=\$(echo "\$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "\$FILE" ]] && exit 0
[[ ! -f "\$FILE" ]] && exit 0
HOOK

case "$FORMATTER" in
  biome)   echo 'npx @biomejs/biome format --write "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  ruff)    echo 'ruff format "$FILE" 2>/dev/null || black "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  gofmt)   echo 'gofmt -w "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  rustfmt) echo 'rustfmt "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  *)       echo 'npx prettier --write "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
esac

# --- stop-quality-gate.sh (uses actual detected commands) ---
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

# --- teammate-quality-gate.sh (only if agent teams enabled) ---
if [ "$AGENT_TEAMS" = "true" ]; then
cat > .claude/hooks/teammate-quality-gate.sh <<HOOK
#!/usr/bin/env bash
set -euo pipefail
INPUT=\$(cat)
TEAMMATE=\$(echo "\$INPUT" | jq -r '.teammate_name // "teammate"')
TASK=\$(echo "\$INPUT" | jq -r '.task_subject // "current task"')
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
  printf "%s: fix before marking '%s' done:\n%b" "\$TEAMMATE" "\$TASK" "\$ERRORS" >&2
  exit 2
fi
exit 0
HOOK
fi

# --- task-summary.sh ---
cat > .claude/hooks/task-summary.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
{
  echo "# Session — $TIMESTAMP | Branch: $BRANCH"
  echo ""
  git diff --stat HEAD 2>/dev/null || git status --short
  echo ""
  git log --oneline -5 2>/dev/null
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
{ echo "# WIP — $(date)"; echo "$CUSTOM"; echo ""; git status --short 2>/dev/null; } > "$SCRATCH"
echo "Context saved to $SCRATCH" >&2
exit 0
HOOK

# --- session-start.sh ---
cat > .claude/hooks/session-start.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
[[ "$AGENT_TYPE" == "subagent" || "$AGENT_TYPE" == "teammate" ]] && exit 0
echo "## Git State"
cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "(not a git repo)"
echo ""
echo "## Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
echo ""
echo "## Recent Commits"
git log --oneline -5 2>/dev/null || echo "(no commits)"
exit 0
HOOK

chmod +x .claude/hooks/*.sh

echo "Hook scripts written and made executable" >&2
HOOKS="guard.sh format.sh stop-quality-gate.sh task-summary.sh save-context.sh session-start.sh"
[ "$AGENT_TEAMS" = "true" ] && HOOKS="$HOOKS teammate-quality-gate.sh"
echo "{\"status\":\"ok\",\"files\":\"$HOOKS\"}"
```

---

## Step 8 — Create `skills/brownfield/scripts/generate-settings.sh`

Same as greenfield's generate-settings.sh — writes `.claude/settings.json`
and `.claude/settings.local.json`. Agent teams hook entries are included
only if `AGENT_TEAMS=true`.

Copy the full content from `skills/greenfield/scripts/generate-settings.sh`
verbatim, then add these two blocks inside `settings.json` if `AGENT_TEAMS=true`:

```json
"TeammateIdle": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-quality-gate.sh\""
      }
    ]
  }
],
"TaskCompleted": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-quality-gate.sh\""
      }
    ]
  }
]
```

Note: VS Code may show schema warnings on `TeammateIdle` and `TaskCompleted`.
This is a known schema lag — the hooks work correctly at runtime. Suppress with:
```json
{ "json.schemas": [{ "fileMatch": ["**/.claude/settings.json"], "schema": {} }] }
```
in `.vscode/settings.json`.

---

## Step 9 — Create `skills/brownfield/scripts/generate-claude-md.sh`

Writes `CLAUDE.md` using discovered values — not placeholders.

```bash
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
```

---

## Step 10 — Create `skills/brownfield/scripts/generate-gitignore.sh`

Copy this file verbatim from `skills/greenfield/scripts/generate-gitignore.sh`.
The content is identical — appends Claude Code entries to `.gitignore`.

---

## Step 11 — Create `skills/brownfield/references/rules-templates.md`

Copy the content from the previously downloaded
`brownfield/references/rules-templates.md` file verbatim.

This file contains content guidelines for each rules file — used by the
skill's Step 4 to ensure rules contain real codebase examples, not placeholders.

---

## Step 12 — Create `skills/brownfield/references/hook-detection.md`

Copy the content from the previously downloaded
`brownfield/references/hook-detection.md` file verbatim.

This file describes which hooks to recommend based on what the analysis scripts
find — used during the human review checkpoint presentation.

---

## Step 13 — Package the Skill

```bash
cd skills
zip -r brownfield.zip brownfield/
```

---

## Step 14 — Verify Structure

```bash
find skills/brownfield -type f | sort
```

Expected output:
```
skills/brownfield/SKILL.md
skills/brownfield/references/hook-detection.md
skills/brownfield/references/rules-templates.md
skills/brownfield/scripts/analyze-conventions.sh
skills/brownfield/scripts/analyze-git.sh
skills/brownfield/scripts/analyze-repo.sh
skills/brownfield/scripts/analyze-tests.sh
skills/brownfield/scripts/generate-claude-md.sh
skills/brownfield/scripts/generate-gitignore.sh
skills/brownfield/scripts/generate-hooks.sh
skills/brownfield/scripts/generate-rules.sh
skills/brownfield/scripts/generate-settings.sh
```

Verify scripts are executable:
```bash
ls -la skills/brownfield/scripts/
```

---

## Key Differences from Greenfield

| Concern | Greenfield | Brownfield |
|---|---|---|
| Conventions | Developer defines in interview | Scripts detect from codebase |
| Analysis phase | None — starts from scratch | 4 parallel analysis scripts |
| Human checkpoint | Interview before generation | Review + confirm findings before generation |
| Rules content | Generic best practices for stack | Real examples from actual codebase |
| Hook commands | Set from interview answers | Detected from package.json/go.mod/etc |
| CLAUDE.md | Mostly placeholder content | Populated with real commands and commit examples |
| Agent teams hooks | Set from interview answer | Set from developer answer at checkpoint |

---

## Notes for CC

- Steps 8 and 10 reference other skill files — copy those scripts verbatim.
- Steps 11 and 12 reference previously downloaded files — copy those verbatim.
- All `.sh` files must be executable (`chmod +x`) after creation.
- Scripts output JSON to stdout and status messages to stderr — preserve this pattern.
- The `/tmp/bf-*.json` files are the communication channel between analysis and generation phases.
