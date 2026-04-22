# Workflow Skill

Installs the full development command layer into a project that already has Claude Code foundation config from the greenfield or brownfield skill.

## Installation

```bash
npx skills add squirrelsoft-dev/agent-skills@workflow
```

**Run greenfield or brownfield first.** Workflow requires an existing `.claude/` directory.

## Trigger

- `/workflow`
- "install workflow"
- "set up commands"
- "set up agents"

---

## What it installs

### Slash commands

Installed to `.claude/commands/`. The `breakdown`, `spec`, and `work` commands are installed in the variant that matches your orchestration mode choice at setup (loop / subagents / teams).

| Command | Doc |
|---|---|
| `/breakdown` | [→ breakdown](../commands/breakdown.md) |
| `/spec` | [→ spec](../commands/spec.md) |
| `/work` | [→ work](../commands/work.md) |
| `/commit` | [→ commit](../commands/commit.md) |
| `/review` | [→ review](../commands/review.md) |
| `/pr` | [→ pr](../commands/pr.md) |
| `/squash-pr` | [→ squash-pr](../commands/squash-pr.md) |
| `/address-pr-comments` | [→ address-pr-comments](../commands/address-pr-comments.md) |
| `/fix-issue` | [→ fix-issue](../commands/fix-issue.md) |
| `/security-scan` | [→ security-scan](../commands/security-scan.md) |
| `/triage` | [→ triage](../commands/triage.md) |
| `/update-skills` | Refresh installed skills to their latest versions |

### Agents

Installed to `.claude/agents/`. The exact set depends on orchestration mode.

| Agent | Modes | Purpose |
|---|---|---|
| `planner` | loop | Produces a PLAN block per spec (opus) |
| `executor` | loop | Implements a plan, no commits (haiku) |
| `evaluator` | loop | Per-spec mini-QA: lint, typecheck, test, spec-compliance (sonnet) |
| `quality` | loop, subagents, teams | Final 8-gate quality pass (sonnet) |
| `architect` | all | Designs features and architecture |
| `manager` | teams | Coordinates group execution across domain teammates |
| `git-expert` | all | Manages worktrees, merges, pushes, and PRs |

### Triage skill

Installed to `.claude/skills/triage/` (requires gh CLI).

→ [Triage command documentation](../commands/triage.md)

---

## Orchestration modes

**Subagents — PEE loop (recommended)** — per spec, a sequential Planner → Executor → Evaluator loop runs on a shared branch, with one full 8-gate quality pass at the end. One-shot subagents, no team infrastructure. Gates 1–4 (lint, typecheck, build, test) run in a quality subagent; gates 5–8 (simplify, review, security-review, security-scan) run in the main agent via the `Skill` tool (subagents can't invoke skills). Optimized for spec-compliance correctness.

**Subagents — parallel** — parallel workers in isolated git worktrees, merged by the git-expert agent. Stable, works everywhere; best for independent tasks where throughput matters.

**Agent teams (experimental)** — persistent teammates own parallel domains of the codebase on a shared branch, receiving tasks one group at a time. After each group completes, the main agent spawns a dedicated Quality Gate agent that runs all 8 gates with fix-loops per gate. This keeps retry context in the Quality Gate agent rather than accumulating in the main agent. Requires CC v2.1.32+ and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled.
