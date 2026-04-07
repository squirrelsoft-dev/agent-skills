# Workflow Skill

> 🚧 This skill is currently in development.

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

Installed to `.claude/commands/`. The breakdown/spec/work trio is installed in either subagents or agent teams variant based on your choice at setup.

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

### Agents

Installed to `.claude/agents/`.

| Agent | Purpose |
|---|---|
| architect | Plans features and architecture |
| implementer | Implements specs (subagents mode) |
| domain-implementer | Implements specs by domain, one group at a time (agent teams mode) |
| quality-gate | 8-gate quality review (spawned between groups in teams mode) |
| git-expert | Manages worktrees, merges, and verification |

### Triage skill

Installed to `.claude/skills/triage/` (requires gh CLI).

→ [Triage command documentation](../commands/triage.md)

---

## Orchestration modes

**Subagents (recommended)** — parallel workers in isolated git worktrees, merged by the git-expert agent. Stable, works everywhere.

**Agent teams** — persistent domain-implementer teammates work on a shared branch, receiving tasks one group at a time. After each group completes, the main agent spawns a dedicated Quality Gate agent that runs all 8 gates (lint, typecheck, build, test, simplify, review, security-review, security-scan) with fix-loops per gate. This keeps retry context in the Quality Gate agent (~7% of main context) rather than accumulating in the main agent. Requires CC v2.1.32+ and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled.
