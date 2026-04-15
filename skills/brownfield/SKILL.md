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
disable-model-invocation: true
allowed-tools: Bash Read Write Glob AskUserQuestion
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
command -v jq &>/dev/null && echo "jq: installed" || echo "jq: MISSING — required for brownfield analysis"
```

If `.claude/` already exists, ask the developer:
> "A `.claude/` directory already exists. Running this will overwrite it.
> Continue, or run the greenfield skill instead for a fresh setup?"

Wait for confirmation before proceeding.

If `jq` is not installed, stop and instruct:
> "The brownfield skill requires `jq` for JSON processing. Install it first:
> `sudo apt-get install jq` (Debian/Ubuntu) or `brew install jq` (macOS)."

---

## Step 2 — Parallel Analysis

Run all four analysis scripts. Use subagents in parallel if available,
otherwise run sequentially. All scripts are read-only — no files are
written in this phase.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/analyze-repo.sh"        > /tmp/bf-repo.json
bash "${CLAUDE_SKILL_DIR}/scripts/analyze-conventions.sh" > /tmp/bf-conventions.json
bash "${CLAUDE_SKILL_DIR}/scripts/analyze-git.sh"         > /tmp/bf-git.json
bash "${CLAUDE_SKILL_DIR}/scripts/analyze-tests.sh"       > /tmp/bf-tests.json
```

Verify all four JSON files are valid:
```bash
jq . /tmp/bf-repo.json /tmp/bf-conventions.json /tmp/bf-git.json /tmp/bf-tests.json >/dev/null
```

---

## Step 3 — Human Review Checkpoint

Synthesize findings from the four JSON outputs and present this summary.
Do NOT write any files yet.

Load reference files for context:
- Rules content guidelines: `${CLAUDE_SKILL_DIR}/references/rules-templates.md`
- Hook recommendations: `${CLAUDE_SKILL_DIR}/references/hook-detection.md`

Present findings:

```
## Brownfield Analysis — [Project Name from basename $PWD]

### Stack & Runtime
[language, framework, versions, package manager from bf-repo.json]

### Conventions Detected
[naming, imports, formatting from bf-conventions.json — with real file examples from the codebase]

### Testing
[framework, file locations, exact run command from bf-tests.json]

### Git & Collaboration
[commit style with 3 real examples from bf-git.json, branch pattern, CI platform]

### ⚠️ Conflicts & Ambiguities
[list any competing conventions that need a human decision]
[e.g. "Files in /legacy use snake_case, files in /src use camelCase — which is current?"]

### Tech Debt Signals
[TODO/FIXME density, files untouched 12+ months, deprecated patterns]
```

Detect and report quality tools:
```bash
command -v gitleaks &>/dev/null && echo "gitleaks: installed" || echo "gitleaks: missing"
command -v semgrep  &>/dev/null && echo "semgrep: installed"  || echo "semgrep: missing"
command -v gh       &>/dev/null && echo "gh CLI: installed"   || echo "gh CLI: missing"
```

For any missing tools, list what they do and how to install them:

```
Recommended tools (install before running /workflow):

  gitleaks — Secret/credential detection
    https://github.com/gitleaks/gitleaks#installing

  semgrep — SAST security scanner
    https://semgrep.dev/docs/getting-started/

  gh CLI — Required for /triage, /pr, /squash-pr, /address-pr-comments
    https://cli.github.com/
```

Do NOT offer to install these tools automatically.

### Check for Previous Configuration

Before asking interview questions, check if this skill has been run before:

```bash
SKILL_NAME="brownfield" \
bash "${CLAUDE_SKILL_DIR}/scripts/load-config.sh"
```

If the output is a non-empty JSON object (not `{}`), previous answers exist. Present the analysis summary above **and** the saved answers:

```
Previous brownfield configuration found:

  Agent teams:   [AGENT_TEAMS]
  Commit style:  [COMMIT_STYLE]
  CI/CD:         [CI_CD]
  Corrections:   [CORRECTIONS or "none"]

Would you like to:
  a) Update — use these settings with the fresh analysis above and regenerate artifacts
  b) Reconfigure — answer all questions from scratch
```

Use `AskUserQuestion` and wait for the response.

- If **Update**: load saved values into environment variables. If the fresh analysis reveals new conflicts or ambiguities not covered by saved corrections, ask only about those. Then **skip to Step 3b**.
- If **Reconfigure**: proceed to the full interview below.

If no previous config exists, ask all questions:

1. Does this match your understanding? Correct anything that's wrong.
2. For any conflicts listed above — which convention is the current standard?
3. Enable agent teams? (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — yes / no
4. Commit style going forward? — detected style / conventional commits / free-form
5. Scaffold GitHub Actions CI if none detected? — yes / no

**Wait for developer response before proceeding.**

### Save Configuration

After the interview (or after loading previous config for an update), save the current answers:

```bash
SKILL_NAME="brownfield" \
CONFIG_JSON='{"AGENT_TEAMS":"[val]","COMMIT_STYLE":"[val]","CI_CD":"[val]","CORRECTIONS":"[val]"}' \
bash "${CLAUDE_SKILL_DIR}/scripts/save-config.sh"
```

Replace `[val]` with actual values. `CORRECTIONS` should be a JSON-escaped string of any corrections the developer made to the analysis. This writes to `.claude/skill-config.json` so future runs can reuse these answers.

**Proceed to Step 3b.**

---

## Step 3b — Architectural Analysis

After the developer confirms script findings, run a deeper analysis of the
actual codebase to identify patterns that scripts can't detect.

Load the investigation guide:
`${CLAUDE_SKILL_DIR}/references/architecture-analysis.md`

Use an Explore subagent (`context: fork`) to read the codebase. The subagent
should use the confirmed stack, org pattern, and file locations from the
analysis JSON as a starting point to know where to look.

### What to investigate

1. **Dependency and call patterns** — centralized clients, import graph, service layers
2. **Architectural boundaries** — top-level directory responsibilities, frozen/legacy areas
3. **Error handling patterns** — centralized handlers, custom error classes, consistent shapes
4. **Auth and permissions patterns** — middleware, guards, decorators, role checks
5. **State management patterns** — local vs global state, server state (React Query/SWR)
6. **Testing patterns** — shared utilities, custom matchers, mock strategies
7. **Git history patterns** — co-change coupling, high-churn areas (if `gh` CLI available)

### Output

Generate additional `.claude/rules/` files only when genuine patterns are found.
Do not pad with generic advice. Example files:
- `architecture.md` — if clear architectural layers or centralized patterns found
- `legacy.md` — if frozen/deprecated directories found
- `gotchas.md` — if project-specific traps discovered

### Developer review

Present generated rules for review before writing:

```
## Additional Rules Generated from Codebase Analysis

I identified these architectural patterns and generated corresponding rules:

**architecture.md** — centralized API client pattern, feature boundary enforcement
**gotchas.md** — 3 project-specific traps found

Preview:
[show first few lines of each file]

Are these accurate? I can:
- Accept all and proceed
- Edit any file before committing
- Skip specific files
```

Wait for developer confirmation. Then proceed to Step 4.

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
bash "${CLAUDE_SKILL_DIR}/scripts/generate-rules.sh"
```

### 4b — Hooks
```bash
STACK="[from bf-repo.json]" \
PKG_MANAGER="[from bf-repo.json]" \
FORMATTER="[from bf-repo.json]" \
TEST_RUNNER="[from bf-repo.json, e.g. vitest/jest/pytest/go-test]" \
TYPECHECKER="[python only — ty/pyright/mypy, ask at interview if unset]" \
AGENT_TEAMS="[from developer answer]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-hooks.sh"
```

### 4c — Settings
```bash
PROJECT_DIR="$PWD" \
PKG_MANAGER="[from bf-repo.json]" \
AGENT_TEAMS="[from developer answer]" \
LINT_CMD="[from bf-repo.json]" \
TEST_CMD="[from bf-repo.json]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-settings.sh"
```

### 4d — CLAUDE.md
```bash
REPO_JSON="/tmp/bf-repo.json" \
GIT_JSON="/tmp/bf-git.json" \
PROJECT_NAME="[detected or asked]" \
COMMIT_STYLE="[from developer answer]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-claude-md.sh"
```

### 4e — .gitignore
```bash
PROJECT_DIR="$PWD" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-gitignore.sh"
```

Content guidelines for rules: `${CLAUDE_SKILL_DIR}/references/rules-templates.md`
Hook recommendations: `${CLAUDE_SKILL_DIR}/references/hook-detection.md`

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

- Rules content guidelines: `${CLAUDE_SKILL_DIR}/references/rules-templates.md`
- Hook recommendation logic: `${CLAUDE_SKILL_DIR}/references/hook-detection.md`
