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

## Step 1 — Preflight & Stack Detection

If `.claude/` already exists, ask:
> "A `.claude/` directory already exists. This will overwrite it.
> Continue, or run `/brownfield` instead to analyze what's already here?"

Wait for confirmation before proceeding.

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

## Step 2 — Developer Interview

**Present all questions at once** before generating anything.
Load the full question set from:
`${CLAUDE_SKILL_DIR}/references/interview.md`

Ask all 7 questions (project name, description, stack confirmation, git setup, agent teams, commit style, CI/CD). **Wait for the developer to answer all questions before proceeding to Step 3.**

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

## Step 4 — Generate All Artifacts

Run each script with the correct environment variables. All scripts require `PROJECT_DIR`.
Scripts can run in parallel — they write to separate paths and have no interdependencies.

### 4a — Settings

```bash
PROJECT_DIR="$PWD" \
AGENT_TEAMS="[true/false from Q5]" \
PKG_MANAGER="[from detection]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-settings.sh"
```

### 4b — Rules

```bash
PROJECT_DIR="$PWD" \
STACK="[confirmed stack from Q3]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-rules.sh"
```

### 4c — Hooks

```bash
PROJECT_DIR="$PWD" \
LINT_CMD="[from stack reference]" \
TEST_CMD="[from stack reference]" \
FORMATTER="[from detection]" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-hooks.sh"
```

### 4d — CLAUDE.md

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

### 4e — .gitignore

```bash
PROJECT_DIR="$PWD" \
bash "${CLAUDE_SKILL_DIR}/scripts/generate-gitignore.sh"
```

Each script outputs JSON status to stdout (e.g. `{"status":"ok","files":[...]}`). Check that all return `"status":"ok"`. If any fail, report the error and stop.

---

## Step 5 — Git Setup (if requested)

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

## Step 6 — CI/CD (if requested)

Only if the developer chose `yes` in Q7.

Load templates from:
`${CLAUDE_SKILL_DIR}/references/ci-templates.md`

Generate `.github/workflows/` files for each selected workflow (lint, test, build, deploy).
Replace placeholder values (`$PKG_MANAGER`, `$INSTALL_CMD`, `$LINT_CMD`, `$TEST_CMD`, `$BUILD_CMD`) with the actual values from stack detection and the stack reference.

If git was initialized in Step 5, stage and commit the CI files:

```bash
git add .github/
git commit -m "ci: add GitHub Actions workflows"
```

---

## Step 7 — Completion

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
