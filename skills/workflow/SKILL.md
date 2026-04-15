---
name: workflow
description: >
  Install the full development workflow into a Claude Code project: slash commands
  for breakdown, spec, work, commit, review, PR, security scanning, and issue
  triage; agents for architecture, implementation, quality review, and git
  management. Run this after the greenfield or brownfield skill has set up the
  project foundation. Trigger phrases: "/workflow", "install workflow", "set up
  commands", "set up agents", "install breakdown and work commands",
  "configure my workflow", "install the development workflow".
---

# Workflow Setup

Installs the development workflow layer. Requires an existing `.claude/` directory
— run the greenfield or brownfield skill first.

---

## Step 1 — Preflight

Check that prerequisites exist:

```bash
ls .claude/ 2>/dev/null || echo "MISSING"
ls .claude/hooks/stop-quality-gate.sh 2>/dev/null && echo "GATE_EXISTS" || echo "GATE_MISSING"
cat .claude/settings.json 2>/dev/null | grep -q "AGENT_TEAMS" && echo "TEAMS_ENABLED" || echo "TEAMS_DISABLED"
```

If `.claude/` is missing, stop:
> "No .claude/ directory found. Run the greenfield or brownfield skill first,
> then re-run /workflow."

If `.claude/commands/` or `.claude/agents/` already have files, warn:
> "Existing commands/agents will be overwritten. Continue? (yes/no)"

---

## Step 2 — Check for Previous Configuration

Before starting the interview, check if this skill has been run before:

```bash
SKILL_NAME="workflow" \
bash "${CLAUDE_SKILL_DIR}/scripts/load-config.sh"
```

If the output is a non-empty JSON object (not `{}`), previous answers exist. Present them:

```
Previous workflow configuration found:

  Orchestration: [ORCHESTRATION]
  Commands:      [COMMANDS]
  Gitleaks:      [GITLEAKS]
  Semgrep:       [SEMGREP]

Would you like to:
  a) Update — reinstall all commands and agents using these settings
  b) Reconfigure — start the interview from scratch
```

Use `AskUserQuestion` and wait for the response.

- If **Update**: load all saved values into environment variables and **skip to Step 3**.
- If **Reconfigure**: proceed to the full interview below.

If no previous config exists, proceed directly to the interview.

---

## Step 2b — Interview

Ask each question using `AskUserQuestion` and wait for the response before proceeding to the next question.

### Question 1 — Orchestration Mode

Use `AskUserQuestion` with this prompt:

```
Setting up your development workflow.

Orchestration mode — How should /breakdown, /spec, and /work orchestrate agents?

  a) Subagents (recommended) — parallel workers in isolated git worktrees,
     merged by the git-expert agent. Stable, works everywhere.

  b) Agent teams (experimental) — teammates work on parallel domains of the
     codebase on a shared branch. Requires CC v2.1.32+ and
     CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS enabled.

  c) PEE loop — sequential Planner → Executor → Evaluator loop per spec on a
     shared branch, with one full quality pass at the end. Optimized for
     spec-compliance correctness, not raw speed. Uses opus for planner/evaluator
     and sonnet for the executor. Requires agent teams enabled.
```

### Question 2 — Commands

Use `AskUserQuestion` with this prompt:

```
Which commands would you like installed? (default: all)

  a) /breakdown, /spec, /work  — feature planning and implementation   ✓
  b) /commit                   — conventional commit message generator  ✓
  c) /review                   — code review of current changes         ✓
  d) /pr, /squash-pr, /address-pr-comments — pull request workflow      ✓
  e) /fix-issue                — implement a GitHub issue end-to-end    ✓
  f) /security-scan            — on-demand deep security scan           ✓
  g) /triage                   — GitHub issue analysis (requires gh)    ✓
  h) /update-skills            — find and install skills for your deps  ✓

Enter "all" or list letters to include (e.g. "a, b, d"):
```

---

## Step 2c — Save Configuration

After the interview (or after loading previous config for an update), save the current answers:

```bash
SKILL_NAME="workflow" \
CONFIG_JSON='{"ORCHESTRATION":"[val]","COMMANDS":"[val]","GITLEAKS":"[val]","SEMGREP":"[val]"}' \
bash "${CLAUDE_SKILL_DIR}/scripts/save-config.sh"
```

Replace `[val]` with actual values. This writes to `.claude/skill-config.json` so future runs can reuse these answers.

---

## Step 3 — Detect Quality Tools

```bash
bash scripts/detect-tools.sh
```

For any missing tools, list what they do and how to install them. Do NOT offer to install them automatically.

```
Recommended tools:

  gitleaks — Scans for accidentally committed secrets
    https://github.com/gitleaks/gitleaks#installing
    brew install gitleaks

  semgrep — SAST security scanner (injection, OWASP Top 10)
    https://semgrep.dev/docs/getting-started/
    pip install semgrep  /  brew install semgrep

  gh CLI — Required for /triage, /pr, /squash-pr, /address-pr-comments
    https://cli.github.com/
    brew install gh

The quality gate will skip checks for tools that aren't installed.
```

---

## Step 4 — Install Commands and Agents

Run in parallel if subagents are available, otherwise sequential:

```bash
ORCHESTRATION="[subagents|teams|loop]" \
COMMANDS="[comma-separated approved list]" \
bash scripts/install-commands.sh

ORCHESTRATION="[subagents|teams|loop]" \
bash scripts/install-agents.sh
```

If gh CLI is available and /triage was approved:
```bash
bash scripts/install-triage-skill.sh
```

---

## Step 5 — Verify Quality Gate

Confirm the installed `.claude/hooks/stop-quality-gate.sh` is the scoped,
stack-aware template (gitleaks and semgrep are now built into the hook's
shared security block and run only on changed files — no patching needed):

```bash
bash scripts/patch-quality-gate.sh
```

The script is a no-op when the hook is already the scoped template. If it
detects an older unscoped hook, it prints instructions to re-run
greenfield/brownfield to regenerate.

---

## Step 6 — Patch Settings for Agent Teams (if chosen)

If orchestration = `teams` or `loop` (both require agent teams for cross-agent SendMessage):

```bash
bash scripts/patch-settings-teams.sh
```

Adds `TaskCompleted` hook to `.claude/settings.json` that runs `format.sh`
and `task-summary.sh`. Quality gates are handled by the dedicated Quality Gate
agent between groups — no `teammate-quality-gate.sh` is created.

Note to developer after patching:
> VS Code may show schema warnings on `TaskCompleted`.
> This is a known schema lag — agent teams hooks are newer than the schema. The hooks work
> correctly at runtime. To suppress the warning add this to `.vscode/settings.json`:
> `{ "json.schemas": [{ "fileMatch": ["**/.claude/settings.json"], "schema": {} }] }`

---

## Step 7 — Commit

```bash
git add .claude/
git commit -m "chore(claude): install development workflow"
```

---

## Step 8 — Completion

```
✅ Workflow Setup Complete

Commands installed:
  /breakdown + /spec + /work  — [subagents | agent teams] orchestration
  /commit                     — conventional commit message generator
  /review                     — code review of current changes
  /pr + /squash-pr            — pull request workflow
  /address-pr-comments        — address GitHub review comments
  /fix-issue                  — implement a GitHub issue end-to-end
  /security-scan              — on-demand deep security scan
  /triage                     — GitHub issue analysis and planning
  /update-skills              — find and install skills for project dependencies

Agents installed:
  architect                                       — plans features and architecture
  [implementer | domain-implementer | planner+executor+evaluator]  — implement specs
  quality                                         — 8-gate quality review
  git-expert                                      — worktrees, merges, verification

Quality tools:
  gitleaks: [✅ active in quality gate | ⚠️ not installed]
  semgrep:  [✅ active in quality gate | ⚠️ not installed]
  gh CLI:   [✅ installed | ⚠️ not installed — /triage, /pr, /squash-pr need this]

Agent teams hooks: [added to settings.json | not configured]

⚠️ Restart Claude Code to load the new commands and agents.

Typical workflow once restarted:
  /breakdown my-feature     — decompose into tasks
  /spec my-feature          — generate implementation specs
  /work my-feature --all    — implement with agents
  /squash-pr my-feature     — create PR
```

---

## Reference Files

- Commands: `references/commands/`
- Agents: `references/agents/`
- Triage skill: `references/triage-skill.md`
