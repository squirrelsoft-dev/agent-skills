# Workflow Skill — Implementation Plan

This document tells Claude Code exactly what files to create and where.
Follow each step in order. Create files exactly as written.

---

## Overview

The workflow skill installs the development command layer into a project that
already has Claude Code foundation config from the greenfield or brownfield skill.

**What this skill installs:**
- Slash commands: `/breakdown`, `/spec`, `/work`, `/commit`, `/review`, `/pr`,
  `/squash-pr`, `/address-pr-comments`, `/security-scan`, `/triage`, `/fix-issue`
- Agents: architect, implementer (subagents mode) or domain-implementer (teams mode),
  quality-gate, git-expert
- Nested skill: triage (installed to `.claude/skills/triage/`)

The skill runs a short interview, detects available quality tools, installs the
correct version of each command based on orchestration mode, and optionally
patches settings.json for agent teams TaskCompleted hooks (format + task-summary).

---

## Directory Structure to Create

```
skills/
└── workflow/
    ├── SKILL.md
    ├── scripts/
    │   ├── detect-tools.sh              ← detects gitleaks, semgrep, gh CLI
    │   ├── install-commands.sh          ← copies command files to .claude/commands/
    │   ├── install-agents.sh            ← copies agent files to .claude/agents/
    │   ├── install-triage-skill.sh      ← writes .claude/skills/triage/SKILL.md
    │   ├── patch-quality-gate.sh        ← adds gitleaks/semgrep blocks to stop-quality-gate.sh
    │   └── patch-settings-teams.sh      ← adds TaskCompleted hooks (format + task-summary) to settings.json
    └── references/
        ├── commands/
        │   ├── breakdown-subagents.md   ← /breakdown for subagents mode
        │   ├── breakdown-teams.md       ← /breakdown for agent teams mode (combined group+domain format)
        │   ├── spec-subagents.md        ← /spec for subagents mode
        │   ├── spec-teams.md            ← /spec for agent teams mode
        │   ├── work-subagents.md        ← /work for subagents mode
        │   ├── work-teams.md            ← /work for agent teams mode
        │   ├── commit.md
        │   ├── fix-issue.md
        │   ├── pr.md
        │   ├── review.md
        │   ├── security-scan.md
        │   ├── squash-pr.md
        │   └── address-pr-comments.md
        ├── agents/
        │   ├── architect.md
        │   ├── implementer.md
        │   ├── domain-implementer.md
        │   ├── quality.md
        │   └── git-expert.md
        └── triage-skill.md              ← content for the triage nested skill
```

---

## Step 1 — Create `skills/workflow/SKILL.md`

```markdown
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

Ask each question using `AskUserQuestion` and wait for the response before proceeding to the next question.

### Question 1 — Orchestration Mode

Use `AskUserQuestion` with this prompt:

```
Setting up your development workflow.

Orchestration mode — How should /breakdown, /spec, and /work orchestrate agents?

  a) Subagents (recommended) — parallel workers in isolated git worktrees,
     merged by the git-expert agent. Stable, works everywhere.

  b) Agent teams — persistent domain teammates receive work one group at a
     time on a shared branch, with a Quality Gate agent running all 8 gates
     between groups. Requires CC v2.1.32+ and
     CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS enabled.
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

Enter "all" or list letters to include (e.g. "a, b, d"):
```

---

## Step 3 — Detect Quality Tools

```bash
bash scripts/detect-tools.sh
```

For any missing tools, list what they do and how to install them. Do NOT offer to install them automatically.

- **gitleaks** — scans for accidentally committed secrets. https://github.com/gitleaks/gitleaks#installing
- **semgrep** — SAST security scanner, catches injection and OWASP issues. https://semgrep.dev/docs/getting-started/
- **gh CLI** — required for /triage, /pr, /squash-pr, /address-pr-comments. https://cli.github.com/

The quality gate will skip checks for tools that aren't installed.

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

Adds `TaskCompleted` hooks to `.claude/settings.json` that run `format.sh` and
`task-summary.sh`. Quality gates are not run per-task — they are handled by the
dedicated Quality Gate agent spawned between groups.

Note to developer after patching:
> VS Code may show schema warnings on `TaskCompleted`.
> This is a known schema lag — agent teams hooks work correctly at runtime.
> To suppress the warning add this to `.vscode/settings.json`:
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

Agents installed:
  architect                           — plans features and architecture
  [implementer | domain-implementer]  — implements specs [per-group in teams mode]
  quality-gate                        — 8-gate quality review (between groups in teams mode)
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
```

---

## Step 2 — Create `skills/workflow/scripts/detect-tools.sh`

```bash
#!/bin/bash
set -e
# detect-tools.sh
# Detects available quality and workflow tools.
# Output: JSON to stdout. Status: stderr.

echo "Detecting tools..." >&2

GITLEAKS="no"; SEMGREP="no"; GH_CLI="no"; TRIVY="no"

command -v gitleaks &>/dev/null && GITLEAKS="yes"
command -v semgrep  &>/dev/null && SEMGREP="yes"
command -v gh       &>/dev/null && GH_CLI="yes"
command -v trivy    &>/dev/null && TRIVY="yes"

echo "gitleaks=$GITLEAKS semgrep=$SEMGREP gh=$GH_CLI trivy=$TRIVY" >&2

cat <<EOF
{
  "gitleaks": "$GITLEAKS",
  "semgrep": "$SEMGREP",
  "gh_cli": "$GH_CLI",
  "trivy": "$TRIVY"
}
EOF
```

---

## Step 3 — Create `skills/workflow/scripts/install-commands.sh`

Reads content from `references/commands/` and copies to `.claude/commands/`.
Installs the correct mode-specific version of breakdown/spec/work.

```bash
#!/bin/bash
set -e
# install-commands.sh
# Copies command reference files to .claude/commands/
# ORCHESTRATION: "subagents" or "teams"
# COMMANDS: comma-separated list of approved command groups

echo "Installing slash commands..." >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$SCRIPT_DIR/../references/commands"
mkdir -p .claude/commands

ORCHESTRATION="${ORCHESTRATION:-subagents}"
COMMANDS="${COMMANDS:-breakdown,commit,review,pr,fix-issue,security-scan,triage}"

# breakdown / spec / work — install mode-specific version
if echo "$COMMANDS" | grep -q "breakdown"; then
  if [ "$ORCHESTRATION" = "teams" ]; then
    cp "$REFS/breakdown-teams.md" .claude/commands/breakdown.md
    cp "$REFS/spec-teams.md"      .claude/commands/spec.md
    cp "$REFS/work-teams.md"      .claude/commands/work.md
    echo "Installed breakdown/spec/work (agent teams mode)" >&2
  else
    cp "$REFS/breakdown-subagents.md" .claude/commands/breakdown.md
    cp "$REFS/spec-subagents.md"      .claude/commands/spec.md
    cp "$REFS/work-subagents.md"      .claude/commands/work.md
    echo "Installed breakdown/spec/work (subagents mode)" >&2
  fi
fi

echo "$COMMANDS" | grep -q "commit"    && cp "$REFS/commit.md"              .claude/commands/commit.md
echo "$COMMANDS" | grep -q "review"    && cp "$REFS/review.md"              .claude/commands/review.md
echo "$COMMANDS" | grep -q "pr"        && cp "$REFS/pr.md"                  .claude/commands/pr.md
echo "$COMMANDS" | grep -q "pr"        && cp "$REFS/squash-pr.md"           .claude/commands/squash-pr.md
echo "$COMMANDS" | grep -q "pr"        && cp "$REFS/address-pr-comments.md" .claude/commands/address-pr-comments.md
echo "$COMMANDS" | grep -q "fix-issue" && cp "$REFS/fix-issue.md"           .claude/commands/fix-issue.md
echo "$COMMANDS" | grep -q "security"  && cp "$REFS/security-scan.md"       .claude/commands/security-scan.md

INSTALLED=$(ls .claude/commands/ | tr '\n' ' ')
echo "Commands installed: $INSTALLED" >&2
echo "{\"status\":\"ok\",\"installed\":\"$INSTALLED\"}"
```

---

## Step 4 — Create `skills/workflow/scripts/install-agents.sh`

Reads content from `references/agents/` and copies to `.claude/agents/`.
Installs either implementer or domain-implementer based on orchestration mode.

```bash
#!/bin/bash
set -e
# install-agents.sh
# Copies agent definition files to .claude/agents/
# ORCHESTRATION: "subagents" or "teams"

echo "Installing agents..." >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$SCRIPT_DIR/../references/agents"
mkdir -p .claude/agents

ORCHESTRATION="${ORCHESTRATION:-subagents}"

# architect, quality, and git-expert always installed
cp "$REFS/architect.md"  .claude/agents/architect.md
cp "$REFS/quality.md"    .claude/agents/quality.md
cp "$REFS/git-expert.md" .claude/agents/git-expert.md

# implementer variant depends on mode
if [ "$ORCHESTRATION" = "teams" ]; then
  cp "$REFS/domain-implementer.md" .claude/agents/domain-implementer.md
  echo "Installed domain-implementer (agent teams mode)" >&2
else
  cp "$REFS/implementer.md" .claude/agents/implementer.md
  echo "Installed implementer (subagents mode)" >&2
fi

INSTALLED=$(ls .claude/agents/ | tr '\n' ' ')
echo "Agents installed: $INSTALLED" >&2
echo "{\"status\":\"ok\",\"installed\":\"$INSTALLED\"}"
```

---

## Step 5 — Create `skills/workflow/scripts/install-triage-skill.sh`

Creates the triage nested skill at `.claude/skills/triage/SKILL.md`.

```bash
#!/bin/bash
set -e
# install-triage-skill.sh
# Installs the triage skill to .claude/skills/triage/
# Requires gh CLI to be installed.

echo "Installing triage skill..." >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p .claude/skills/triage

cp "$SCRIPT_DIR/../references/triage-skill.md" .claude/skills/triage/SKILL.md

echo "Triage skill installed at .claude/skills/triage/SKILL.md" >&2
echo '{"status":"ok","path":".claude/skills/triage/SKILL.md"}'
```

---

## Step 6 — Create `skills/workflow/scripts/patch-quality-gate.sh`

Adds gitleaks and/or semgrep scan blocks to the existing `stop-quality-gate.sh`.
Looks for `# Lint` as the insertion point — inserts security blocks before it.

```bash
#!/bin/bash
set -e
# patch-quality-gate.sh
# Adds quality tool scan blocks to .claude/hooks/stop-quality-gate.sh
# GITLEAKS: "yes" or "no"
# SEMGREP: "yes" or "no"
# STACK: detected stack (for npm audit block)

GATE=".claude/hooks/stop-quality-gate.sh"

if [ ! -f "$GATE" ]; then
  echo "stop-quality-gate.sh not found — skipping patch" >&2
  echo '{"status":"skipped","reason":"gate not found"}'
  exit 0
fi

GITLEAKS="${GITLEAKS:-no}"
SEMGREP="${SEMGREP:-no}"
STACK="${STACK:-unknown}"
PATCHED=()

if [ "$GITLEAKS" = "yes" ] && ! grep -q "gitleaks" "$GATE"; then
  BLOCK='# Secret detection (gitleaks)\nif command -v gitleaks &>/dev/null; then\n  if output=$(gitleaks detect --no-git --source=. --verbose 2>&1 | grep -v "no leaks found" | grep -E "Secret|Finding|leak"); then\n    [[ -n "$output" ]] && ERRORS+="\\n## Secrets Detected\\n\\`\\`\\`\\n${output}\\n\\`\\`\\`\\n"\n  fi\nfi'
  sed -i.bak "/# Lint/i $BLOCK" "$GATE"
  PATCHED+=("gitleaks")
  echo "Added gitleaks block" >&2
fi

if [ "$SEMGREP" = "yes" ] && ! grep -q "semgrep" "$GATE"; then
  BLOCK='# SAST scan (semgrep)\nif command -v semgrep &>/dev/null; then\n  if output=$(semgrep --config=auto --quiet --json 2>/dev/null | jq -r ".results[] | \"\(.path):\(.start.line) \(.check_id)\"" 2>/dev/null); then\n    [[ -n "$output" ]] && ERRORS+="\\n## Security Issues\\n\\`\\`\\`\\n${output}\\n\\`\\`\\`\\n"\n  fi\nfi'
  sed -i.bak "/# Lint/i $BLOCK" "$GATE"
  PATCHED+=("semgrep")
  echo "Added semgrep block" >&2
fi

if echo "$STACK" | grep -qE "nextjs|react|typescript-node" && ! grep -q "npm audit" "$GATE"; then
  BLOCK='# Dependency audit (npm)\nif [[ -f "$CLAUDE_PROJECT_DIR/package.json" ]] && command -v npm &>/dev/null; then\n  if output=$(npm audit --audit-level=high 2>&1) && echo "$output" | grep -q "high\\|critical"; then\n    ERRORS+="\\n## Vulnerable Dependencies\\n\\`\\`\\`\\n$(echo "$output" | tail -15)\\n\\`\\`\\`\\n"\n  fi\nfi'
  sed -i.bak "/# Lint/i $BLOCK" "$GATE"
  PATCHED+=("npm-audit")
  echo "Added npm audit block" >&2
fi

rm -f "$GATE.bak"
PATCHED_STR=$(IFS=','; echo "${PATCHED[*]}")
echo "{\"status\":\"ok\",\"patched\":\"$PATCHED_STR\"}"
```

---

## Step 7 — Create `skills/workflow/scripts/patch-settings-teams.sh`

Adds `TaskCompleted` hooks to `.claude/settings.json` that run `format.sh` and
`task-summary.sh`. No `teammate-quality-gate.sh` is created — quality gates are
handled by the dedicated Quality Gate agent spawned between groups.
Uses jq to safely modify JSON rather than sed.

```bash
#!/bin/bash
set -e
# patch-settings-teams.sh
# Adds TaskCompleted hooks (format + task-summary) to .claude/settings.json

SETTINGS=".claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "settings.json not found — skipping" >&2
  echo '{"status":"skipped","reason":"settings.json not found"}'
  exit 0
fi

if grep -q "TaskCompleted" "$SETTINGS"; then
  echo "Already patched — skipping" >&2
  echo '{"status":"skipped","reason":"already patched"}'
  exit 0
fi

echo "Patching settings.json for agent teams..." >&2

if command -v jq &>/dev/null; then
  FORMAT_CMD='bash "$CLAUDE_PROJECT_DIR/.claude/hooks/format.sh"'
  SUMMARY_CMD='bash "$CLAUDE_PROJECT_DIR/.claude/hooks/task-summary.sh"'
  jq --arg fmt "$FORMAT_CMD" --arg sum "$SUMMARY_CMD" '
    .hooks.TaskCompleted = [{"hooks": [
      {"type": "command", "command": $fmt},
      {"type": "command", "command": $sum}
    ]}]
  ' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  echo "settings.json patched with TaskCompleted hooks (format + task-summary)" >&2
else
  echo "WARNING: jq not found. Manually add TaskCompleted to .claude/settings.json" >&2
fi

echo '{"status":"ok"}'
```

---

## Step 8 — Create reference command files

For each file below, fetch the content directly from `squirrelsoft-dev/cc-toolkit`
on GitHub and copy it verbatim into the path listed.

| File to create | Fetch from cc-toolkit |
|---|---|
| `references/commands/breakdown-subagents.md` | `templates/commands/breakdown.md` |
| `references/commands/breakdown-teams.md` | `templates/commands/breakdown-team.md` |
| `references/commands/spec-subagents.md` | `templates/commands/spec.md` |
| `references/commands/spec-teams.md` | `templates/commands/spec-team.md` |
| `references/commands/work-subagents.md` | `templates/commands/work.md` |
| `references/commands/work-teams.md` | `templates/commands/work-team.md` |
| `references/commands/commit.md` | `templates/commands/commit.md` |
| `references/commands/fix-issue.md` | `templates/commands/fix-issue.md` |
| `references/commands/pr.md` | `templates/commands/pr.md` |
| `references/commands/review.md` | `templates/commands/review.md` |
| `references/commands/security-scan.md` | `templates/commands/security-scan.md` |
| `references/commands/squash-pr.md` | `templates/commands/squash-pr.md` |
| `references/commands/address-pr-comments.md` | `templates/commands/address-pr-comments.md` |

---

## Step 9 — Create reference agent files

| File to create | Fetch from cc-toolkit |
|---|---|
| `references/agents/architect.md` | `templates/agents/architect.md` |
| `references/agents/implementer.md` | `templates/agents/implementer.md` |
| `references/agents/domain-implementer.md` | `templates/agents/domain-implementer.md` |
| `references/agents/quality.md` | `templates/agents/quality.md` |
| `references/agents/git-expert.md` | `templates/agents/git-expert.md` |

---

## Step 10 — Create `references/triage-skill.md`

Fetch from `squirrelsoft-dev/cc-toolkit` → `templates/skills/triage/SKILL.md`
and copy verbatim. This is installed to `.claude/skills/triage/SKILL.md`
in developer projects.

---

## Step 11 — Package the Skill

```bash
cd skills
zip -r workflow.zip workflow/
```

---

## Step 12 — Verify Structure

```bash
find skills/workflow -type f | sort
```

Expected output:
```
skills/workflow/SKILL.md
skills/workflow/references/agents/architect.md
skills/workflow/references/agents/domain-implementer.md
skills/workflow/references/agents/git-expert.md
skills/workflow/references/agents/implementer.md
skills/workflow/references/agents/quality.md
skills/workflow/references/commands/address-pr-comments.md
skills/workflow/references/commands/breakdown-subagents.md
skills/workflow/references/commands/breakdown-teams.md
skills/workflow/references/commands/commit.md
skills/workflow/references/commands/fix-issue.md
skills/workflow/references/commands/pr.md
skills/workflow/references/commands/review.md
skills/workflow/references/commands/security-scan.md
skills/workflow/references/commands/spec-subagents.md
skills/workflow/references/commands/spec-teams.md
skills/workflow/references/commands/squash-pr.md
skills/workflow/references/commands/work-subagents.md
skills/workflow/references/commands/work-teams.md
skills/workflow/references/triage-skill.md
skills/workflow/scripts/detect-tools.sh
skills/workflow/scripts/install-agents.sh
skills/workflow/scripts/install-commands.sh
skills/workflow/scripts/install-triage-skill.sh
skills/workflow/scripts/patch-quality-gate.sh
skills/workflow/scripts/patch-settings-teams.sh
```

Verify scripts are executable:
```bash
ls -la skills/workflow/scripts/
```

---

## Key Design Notes for CC

**Steps 8–10 use the GitHub tool.** Fetch each file from `squirrelsoft-dev/cc-toolkit`
at the path listed. Copy verbatim — do not regenerate or paraphrase. These are the
exact command and agent definitions installed into developer projects.

**install-commands.sh uses `cp`, not `cat`.** It copies files from
`references/commands/` to `.claude/commands/` at runtime. The reference files
are the source of truth.

**patch-quality-gate.sh inserts before `# Lint`.** Greenfield and brownfield
both write that comment into stop-quality-gate.sh as the insertion landmark.
If that comment changes in those skills, update this script too.

**patch-settings-teams.sh requires `jq`** for safe JSON modification.
If jq is unavailable, it prints a manual instruction instead of failing.
No `teammate-quality-gate.sh` is created — quality gates run via a dedicated
Quality Gate agent spawned between groups.

**All `.sh` files must be `chmod +x` after creation.**
