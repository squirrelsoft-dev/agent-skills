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

## Step 2 — Interview

Present all questions at once before doing anything:

```
Setting up your development workflow. A few questions:

1. Orchestration mode — How should /breakdown, /spec, and /work orchestrate agents?

   a) Subagents (recommended) — parallel workers in isolated git worktrees,
      merged by the git-expert agent. Stable, works everywhere.

   b) Agent teams (experimental) — teammates work on parallel domains of the
      codebase on a shared branch. Requires CC v2.1.32+ and
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS enabled.

2. Which commands would you like installed? (default: all)
   a) /breakdown, /spec, /work  — feature planning and implementation   ✓
   b) /commit                   — conventional commit message generator  ✓
   c) /review                   — code review of current changes         ✓
   d) /pr, /squash-pr, /address-pr-comments — pull request workflow      ✓
   e) /fix-issue                — implement a GitHub issue end-to-end    ✓
   f) /security-scan            — on-demand deep security scan           ✓
   g) /triage                   — GitHub issue analysis (requires gh)    ✓
   h) /update-skills            — find and install skills for your deps  ✓
```

Wait for response before proceeding.

---

## Step 3 — Detect Quality Tools

```bash
bash scripts/detect-tools.sh
```

For any missing tools, present a brief recommendation:

- **gitleaks** — scans for accidentally committed secrets. `brew install gitleaks`
- **semgrep** — SAST security scanner, catches injection and OWASP issues. `pip install semgrep`
- **gh CLI** — required for /triage, /pr, /squash-pr, /address-pr-comments. `brew install gh`

Ask: "Should I install any missing tools now, or skip? (all / none / list specific ones)"

---

## Step 4 — Install Commands and Agents

Run in parallel if subagents are available, otherwise sequential:

```bash
ORCHESTRATION="[subagents|teams]" \
COMMANDS="[comma-separated approved list]" \
bash scripts/install-commands.sh

ORCHESTRATION="[subagents|teams]" \
bash scripts/install-agents.sh
```

If gh CLI is available and /triage was approved:
```bash
bash scripts/install-triage-skill.sh
```

---

## Step 5 — Patch Quality Gate (if tools available)

If gitleaks or semgrep are installed (or were just installed):

```bash
GITLEAKS="[yes|no]" \
SEMGREP="[yes|no]" \
STACK="[detected from CLAUDE.md or package.json]" \
bash scripts/patch-quality-gate.sh
```

---

## Step 6 — Patch Settings for Agent Teams (if chosen)

If orchestration = teams:

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
  architect                           — plans features and architecture
  [implementer | domain-implementer]  — implements specs
  quality                             — 4-gate quality review
  git-expert                          — worktrees, merges, verification

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
