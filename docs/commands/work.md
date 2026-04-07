# /work

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/work.md`  
**Requires:** implementer (or domain-implementer) agent, quality agent, git-expert agent

Implements the specs produced by `/spec` using agents. The core implementation command in the development loop.

## Usage

```
/work <feature-name> [--all | --task <task-id>]
```

## Orchestration modes

**Subagents** — each task is implemented in a separate git worktree by an implementer subagent. The git-expert agent merges completed worktrees, resolves conflicts, and runs a final quality gate. Work happens in parallel.

**Agent teams** — persistent domain-implementer teammates each own a domain of the codebase (API, frontend, tests, etc.) and work on a shared branch, receiving tasks one group at a time. After each group completes, the main agent spawns a dedicated Quality Gate agent that runs all 8 gates with fix-loops before the next group begins.

## Quality gate

Before any implementation is accepted, the Quality Gate agent runs an 8-gate review: lint, typecheck, build, test, simplify, review, security-review, and security-scan. Each gate has a fix-loop — failures are corrected before proceeding to the next gate. In agent teams mode, the Quality Gate agent runs between groups rather than per-task, keeping main agent context minimal.

## Previous steps

→ [/breakdown documentation](breakdown.md)  
→ [/spec documentation](spec.md)
