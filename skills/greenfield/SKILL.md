---
name: greenfield
description: >
  Configure Claude Code for a brand new project. Detects your stack, runs a
  short interview, then generates CLAUDE.md, rules, hooks, and settings tailored
  to your project. Invoke manually with /greenfield or "set up Claude Code",
  "initialize Claude", "configure Claude for this project".
disable-model-invocation: true
allowed-tools: Bash Read Write Glob AskUserQuestion
---

# Greenfield Setup

Configures Claude Code for a new project. Everything is generated on the fly
based on the actual stack and developer answers — not copied from generic templates.

**Scope:** Generates project foundation only:
- CLAUDE.md, .claude/rules/, .claude/hooks/, settings.json, settings.local.json, .gitignore
- Optional: git init + first commit, GitHub Actions CI workflows

Run `/workflow` after this to install development commands and agents.

---

## Step 1 — Preflight & Stack Detection

Check whether any files that greenfield would generate already exist. Scan for:
- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/settings.local.json`
- `.claude/rules/` (any `.md` files inside)
- `.claude/hooks/` (any `.sh` files inside)

**Ignore** the `.claude/skills/` directory — that is where installed skills live and is not a conflict.

If **no** conflicting files are found, proceed silently. If **any** conflicting files exist, use `AskUserQuestion` to show the list and ask:

> "The following files already exist and will be overwritten:
> - [list each conflicting file]
>
> Continue and overwrite these, or run `/brownfield` instead to analyze what's already here?"
>
> Choices: **Continue** / **Abort**

Wait for confirmation before proceeding. If they choose Abort, stop.

Run stack detection:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-stack.sh"
```

The script outputs JSON to stdout with: `stack`, `framework`, `lang`, `pkg_manager`, `formatter`, `test_runner`, `has_typescript`. Parse and store all values — they will be used as environment variables for the generator scripts.

If `stack` is `"unknown"`, ask the developer:
> "I couldn't detect your stack. What are you building?
> (e.g. Next.js, React, Node.js API, Python, Go, Rust, .NET)"

Update the detection values based on their answer.

---

## Step 2 — Check for Previous Configuration

Before starting the interview, check if this skill has been run before:

```bash
SKILL_NAME="greenfield" \
bash "${CLAUDE_SKILL_DIR}/scripts/load-config.sh"
```

If the output is a non-empty JSON object (not `{}`), previous answers exist. Present them:

```
Previous greenfield configuration found:

  Project:       [PROJECT_NAME] — [PROJECT_DESCRIPTION]
  Stack:         [STACK]
  Agent teams:   [AGENT_TEAMS]
  Commit style:  [COMMIT_STYLE]
  CI/CD:         [CI_CD]

Would you like to:
  a) Update — regenerate all artifacts using these settings
  b) Reconfigure — start the interview from scratch
```

Use `AskUserQuestion` and wait for the response.

- If **Update**: load all saved values into environment variables and **skip to Step 3**.
- If **Reconfigure**: proceed to the full interview below.

If no previous config exists, proceed directly to the interview.

---

## Step 2b — Developer Interview

Load the question set from:
`${CLAUDE_SKILL_DIR}/references/interview.md`

**Ask questions one at a time using `AskUserQuestion`.** This provides a cleaner experience — the developer sees one focused question with clear choices instead of a wall of text.

For each question:
1. Use `AskUserQuestion` with the question text and suggested options/defaults
2. Wait for the response
3. Store the answer in the corresponding environment variable
4. Move to the next question

Ask all 7 questions (Q1–Q7) in order. Ask **Q6b only if `STACK == python`** — skip it for every other stack and leave `TYPECHECKER` empty. Skip Q7's follow-up if the developer answers "no" to CI/CD. **Do not proceed to Step 2c until all questions are answered.**

---

## Step 2c — Save Configuration

After the interview (or after loading previous config for an update), save the current answers:

```bash
SKILL_NAME="greenfield" \
CONFIG_JSON='{"PROJECT_NAME":"[val]","PROJECT_DESCRIPTION":"[val]","STACK":"[val]","FRAMEWORK":"[val]","LANG":"[val]","PKG_MANAGER":"[val]","FORMATTER":"[val]","TEST_RUNNER":"[val]","TYPECHECKER":"[val or empty]","HAS_TYPESCRIPT":"[val]","GIT_SETUP":"[val]","AGENT_TEAMS":"[val]","COMMIT_STYLE":"[val]","CI_CD":"[val]","CI_WORKFLOWS":"[val]"}' \
bash "${CLAUDE_SKILL_DIR}/scripts/save-config.sh"
```

Replace `[val]` with actual values. This writes to `.claude/skill-config.json` so future runs can reuse these answers.

---

## Step 3 — Load Stack Knowledge

Read the appropriate stack reference file based on the confirmed stack:

| Stack | File |
|---|---|
| Next.js | `${CLAUDE_SKILL_DIR}/references/stacks/nextjs.md` |
| React | `${CLAUDE_SKILL_DIR}/references/stacks/react.md` |
| Node.js / TypeScript | `${CLAUDE_SKILL_DIR}/references/stacks/typescript-node.md` |
| Python | `${CLAUDE_SKILL_DIR}/references/stacks/python.md` |
| Go | `${CLAUDE_SKILL_DIR}/references/stacks/go.md` |
| Unknown/other | Use Claude's training knowledge for that stack |

Extract the command mappings (`INSTALL_CMD`, `DEV_CMD`, `BUILD_CMD`, `TEST_CMD`, `LINT_CMD`) from the stack reference file based on the detected package manager.

---

## Step 3a — Security Tools Check

Check whether security tools used by the quality gate are installed:

```bash
STACK="[confirmed stack]" \
bash "${CLAUDE_SKILL_DIR}/scripts/check-security-tools.sh"
```

The script outputs JSON with the status of gitleaks, semgrep, trivy, and oxlint (oxlint is skipped for non-Node stacks).

**If all relevant tools are installed**, print a brief confirmation and continue:
```
✅ Security tools: gitleaks ✓  semgrep ✓  trivy ✓
```

**If any tools are missing**, list only the missing ones with install instructions:

```
⚠️  Some security tools used by the quality gate are not installed.
The quality gate will skip these checks until they're installed.

Recommended tools:

  gitleaks — Secret/credential detection (finds API keys, tokens, passwords)
    https://github.com/gitleaks/gitleaks#installing
    brew install gitleaks

  semgrep — SAST scanner (injection, XSS, OWASP Top 10)
    https://semgrep.dev/docs/getting-started/
    pip install semgrep  /  brew install semgrep

  trivy — Vulnerability scanner (dependencies, containers, IaC)
    https://trivy.dev/latest/getting-started/installation/
    brew install trivy

  oxlint — Fast linter for JavaScript/TypeScript (Node stacks only)
    https://oxc.rs/docs/guide/usage/linter
    npm install -g oxlint

Install them anytime — the quality gate will pick them up automatically.
```

Continue to Step 5.

---

## Step 5 — Generate All Artifacts

Run each script with the correct environment variables. All scripts require `PROJECT_DIR`.
Scripts can run in parallel — they write to separate paths and have no interdependencies.

### 5a — Settings

```bash
PROJECT_DIR="$PWD" \
AGENT_TEAMS="[true/false from Q5]" \
PKG_MANAGER="[from detection]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-settings.sh"
```

### 5b — Rules

```bash
PROJECT_DIR="$PWD" \
STACK="[confirmed stack from Q3]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-rules.sh"
```

### 5c — Hooks

```bash
PROJECT_DIR="$PWD" \
STACK="[confirmed stack from Q3]" \
PKG_MANAGER="[from detection]" \
FORMATTER="[from detection]" \
TEST_RUNNER="[from detection, e.g. vitest/jest/pytest/go-test]" \
TYPECHECKER="[from Q6b, python only — otherwise leave empty]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-hooks.sh"
```

### 5d — CLAUDE.md

```bash
PROJECT_DIR="$PWD" \
PROJECT_NAME="[from Q1]" \
PROJECT_DESCRIPTION="[from Q2]" \
STACK="[confirmed stack from Q3]" \
INSTALL_CMD="[from stack reference]" \
DEV_CMD="[from stack reference]" \
BUILD_CMD="[from stack reference]" \
TEST_CMD="[from stack reference]" \
LINT_CMD="[from stack reference]" \
COMMIT_STYLE="[from Q6]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-claude-md.sh"
```

### 5e — .gitignore

```bash
PROJECT_DIR="$PWD" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-gitignore.sh"
```

Each script outputs JSON status to stdout (e.g. `{"status":"ok","files":[...]}`). Check that all return `"status":"ok"`. If any fail, report the error and stop.

---

## Step 6 — Git Setup (if requested)

Only if the developer chose `init` in Q4.

Use the commit message based on Q6:
- Conventional: `chore(claude): initialize Claude Code configuration`
- Free-form: `Initialize project with Claude Code configuration`

```bash
git init
git add CLAUDE.md .claude/ .gitignore
git commit -m "[commit message from above]"
```

---

## Step 7 — CI/CD (if requested)

Only if the developer chose `yes` in Q7.

Load templates from:
`${CLAUDE_SKILL_DIR}/references/ci-templates.md`

Generate `.github/workflows/` files for each selected workflow (lint, test, build, deploy).
Replace placeholder values (`$PKG_MANAGER`, `$INSTALL_CMD`, `$LINT_CMD`, `$TEST_CMD`, `$BUILD_CMD`) with the actual values from stack detection and the stack reference.

If git was initialized in Step 6, stage and commit the CI files:

```bash
git add .github/
git commit -m "ci: add GitHub Actions workflows"
```

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
- .gitignore                   (updated)

Next steps:
1. Run /workflow to install development commands and agents
2. Restart Claude Code to load the new configuration
```

If git was initialized, include the commit hash.
If CI/CD was scaffolded, list the workflow files created.

---

## Reference Files

- Full interview questions: `${CLAUDE_SKILL_DIR}/references/interview.md`
- Artifact content specs: `${CLAUDE_SKILL_DIR}/references/artifact-specs.md`
- CI workflow templates: `${CLAUDE_SKILL_DIR}/references/ci-templates.md`
- Stack conventions: `${CLAUDE_SKILL_DIR}/references/stacks/`
