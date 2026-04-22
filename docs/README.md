# agent-skills Documentation

Documentation for the `squirrelsoft-dev/agent-skills` skill collection.

## Skills

Skills configure Claude Code for a project. Run one skill first to set up the foundation, then run `/workflow` to install the development command layer.

| Skill | Purpose | Status |
|---|---|---|
| [greenfield](skills/greenfield.md) | Configure Claude Code for a brand new project | ✅ Available |
| [brownfield](skills/brownfield.md) | Analyze an existing codebase and generate Claude Code config | ✅ Available |
| [workflow](skills/workflow.md) | Install development commands, agents, and the triage skill | ✅ Available |

### Installation

```bash
npx skills add squirrelsoft-dev/agent-skills@greenfield
npx skills add squirrelsoft-dev/agent-skills@brownfield
npx skills add squirrelsoft-dev/agent-skills@workflow
```

---

## Artifacts

Artifacts are the files written into your project by the skills. Each artifact doc explains what it does and which skill creates it.

### Hooks

Hooks are shell scripts that Claude Code runs automatically at specific points during a session.

| Hook | Trigger | Purpose |
|---|---|---|
| [guard.sh](hooks/guard.md) | Before every tool use | Blocks destructive commands and secret exposure |
| [format.sh](hooks/format.md) | After every file write | Auto-formats changed files |
| [stop-quality-gate.sh](hooks/stop-quality-gate.md) | When Claude completes a task | Runs lint + tests, blocks completion on failure |
| [format.sh](hooks/format.md) + [task-summary.sh](hooks/task-summary.md) | TaskCompleted (teams mode) | Auto-formats changed files and writes a session log |
| [save-context.sh](hooks/save-context.md) | Before context compaction | Saves a WIP snapshot to `.claude/scratch/` |
| [session-start.sh](hooks/session-start.md) | When a session starts | Shows current git state |

### Rules

Rules are markdown files that give Claude standing instructions for how to work in your project.

| Rule file | Applies to | Purpose |
|---|---|---|
| [general.md](rules/general.md) | All files | Code quality and hygiene |
| [security.md](rules/security.md) | All files | Security practices |
| [testing.md](rules/testing.md) | Test files | Testing standards |
| [frontend.md](rules/frontend.md) | Components and pages | Frontend-specific rules (Next.js / React) |
| [api.md](rules/api.md) | API routes | API design rules |

### Commands

Commands are slash commands installed by the `workflow` skill.

| Command | Purpose |
|---|---|
| [/breakdown](commands/breakdown.md) | Decompose a feature into tasks |
| [/spec](commands/spec.md) | Generate implementation specs from tasks |
| [/work](commands/work.md) | Implement specs using agents |
| [/commit](commands/commit.md) | Generate a conventional commit message |
| [/review](commands/review.md) | Review current changes |
| [/pr](commands/pr.md) | Create a pull request |
| [/squash-pr](commands/squash-pr.md) | Squash commits and create a PR |
| [/address-pr-comments](commands/address-pr-comments.md) | Address GitHub review comments |
| [/fix-issue](commands/fix-issue.md) | Implement a GitHub issue end-to-end |
| [/security-scan](commands/security-scan.md) | On-demand deep security scan |
| [/triage](commands/triage.md) | Analyze and plan a GitHub issue |
| `/update-skills` | Refresh installed skills to their latest versions |

### Workflows

Visual diagrams of the development loop pipelines.

| Workflow | Description |
|---|---|
| [Breakdown Flow](workflows/breakdown-flow.md) | Task decomposition from feature description or GitHub issue |
| [Spec Flow](workflows/spec-flow.md) | Parallel spec generation from task breakdown |
| [Subagent Work Flow](workflows/subagent-flow.md) | Parallel workers in isolated worktrees, merged by git-expert |
| [Agent Teams Work Flow](workflows/agent-teams-flow.md) | Persistent domain teammates with group-based execution |

The PEE loop mode (recommended) runs Planner → Executor → Evaluator sequentially per spec on a shared branch, with an 8-gate final pass. See [`/work`](commands/work.md) for the full flow.

---

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core) and live in the repo root `tests/` directory (so they aren't shipped to end users by the skills installer).

```bash
bash tests/greenfield/run-tests.sh
bash tests/workflow/run-tests.sh
```

| Directory | What it tests |
|---|---|
| `tests/<skill>/unit/` | Each script in isolation (e.g. detect-stack, generate-hooks, patch-quality-gate) |
| `tests/<skill>/e2e/` | Full pipeline per scenario (Next.js, Python, empty project; subagents / teams / loop mode) |
| `tests/<skill>/fixtures/` | Minimal project files for each test scenario |
| `tests/helpers/` | Shared setup/teardown and assertion functions |

bats-core is auto-installed on first run. Each test runs in a fresh temporary directory.
