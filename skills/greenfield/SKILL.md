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

Run stack detection:

```bash
bash /mnt/skills/user/greenfield/scripts/detect-stack.sh
```

The script outputs JSON to stdout with: `stack`, `framework`, `lang`, `pkg_manager`, `formatter`, `test_runner`, `has_typescript`. Parse and store all values — they will be used as environment variables for the generator scripts.

If `.claude/` already exists, ask:
> "A `.claude/` directory already exists. This will overwrite it.
> Continue, or run `/brownfield` instead to analyze what's already here?"

Wait for confirmation before proceeding.

---

## Step 2 — Stack Detection

Read the JSON output from Step 1. If `stack` is `"unknown"`, ask the developer:
> "I couldn't detect your stack. What are you building?
> (e.g. Next.js, React, Node.js API, Python, Go, Rust, .NET)"

Update the detection values based on their answer.

---

## Step 3 — Developer Interview

**Present all questions at once** before generating anything.
Load the full question set from:
`/mnt/skills/user/greenfield/references/interview.md`

Core questions (always ask):
1. **Project name** — free text (suggest the current directory name as default)
2. **Project description** — 1–2 sentences
3. **Confirm detected stack** — show what was found, ask to correct if wrong
4. **Git setup** — init + first commit? (`init` / `done` / `skip`)
5. **Agent teams** — enable CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS? (yes / no)
6. **Commit style** — conventional commits or free-form?
7. **CI/CD** — scaffold GitHub Actions? (yes / no — if yes, ask which: lint, test, build, deploy)

**Wait for the developer to answer all questions before proceeding to Step 4.**

---

## Step 4 — Load Stack Knowledge

Read the appropriate stack reference file based on the confirmed stack:

| Stack | File |
|---|---|
| Next.js | `/mnt/skills/user/greenfield/references/stacks/nextjs.md` |
| React | `/mnt/skills/user/greenfield/references/stacks/nextjs.md` |
| Node.js / TypeScript | `/mnt/skills/user/greenfield/references/stacks/typescript-node.md` |
| Python | `/mnt/skills/user/greenfield/references/stacks/python.md` |
| Go | `/mnt/skills/user/greenfield/references/stacks/go.md` |
| Unknown/other | Use Claude's training knowledge for that stack |

Extract the command mappings (`INSTALL_CMD`, `DEV_CMD`, `BUILD_CMD`, `TEST_CMD`, `LINT_CMD`) from the stack reference file based on the detected package manager.

---

## Step 5 — Generate All Artifacts

Run each script with the correct environment variables. All scripts require `PROJECT_DIR`.
Scripts can run in parallel — they write to separate paths and have no interdependencies.

### 5a — Settings

```bash
PROJECT_DIR="$PWD" \
AGENT_TEAMS="[true/false from Q5]" \
PKG_MANAGER="[from detection]" \
bash /mnt/skills/user/greenfield/scripts/generate-settings.sh
```

### 5b — Rules

```bash
PROJECT_DIR="$PWD" \
STACK="[confirmed stack from Q3]" \
bash /mnt/skills/user/greenfield/scripts/generate-rules.sh
```

### 5c — Hooks

```bash
PROJECT_DIR="$PWD" \
LINT_CMD="[from stack reference]" \
TEST_CMD="[from stack reference]" \
FORMATTER="[from detection]" \
bash /mnt/skills/user/greenfield/scripts/generate-hooks.sh
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
bash /mnt/skills/user/greenfield/scripts/generate-claude-md.sh
```

### 5e — .gitignore

```bash
PROJECT_DIR="$PWD" \
bash /mnt/skills/user/greenfield/scripts/generate-gitignore.sh
```

Each script outputs JSON status to stdout (e.g. `{"status":"ok","files":[...]}`). Check that all return `"status":"ok"`. If any fail, report the error and stop.

---

## Step 6 — Git Setup (if requested)

Only if the developer chose `init` in Q4:

```bash
git init
git add -A
git commit -m "chore: initialize project with Claude Code configuration"
```

If conventional commits (Q6): use `chore(claude): initialize Claude Code configuration`
If free-form: use `Initialize project with Claude Code configuration`

---

## Step 7 — CI/CD (if requested)

Only if the developer chose `yes` in Q7.

Load templates from:
`/mnt/skills/user/greenfield/references/ci-templates.md`

Generate `.github/workflows/` files for each selected workflow (lint, test, build, deploy).
Replace placeholder values (`$INSTALL_CMD`, `$LINT_CMD`, `$TEST_CMD`, `$BUILD_CMD`) with the actual commands from the stack reference.

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

- Full interview questions: `references/interview.md`
- Artifact content specs: `references/artifact-specs.md`
- CI workflow templates: `references/ci-templates.md`
- Stack conventions: `references/stacks/`
