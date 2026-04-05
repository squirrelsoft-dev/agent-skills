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

**Agent teams** — domain-implementer teammates each own a domain of the codebase (API, frontend, tests, etc.) and work simultaneously on a shared branch. Teammate hooks gate each domain's output before it is accepted.

## Quality gate

Before any implementation is accepted, the quality agent runs a 4-gate review: lint, tests, security scan, and code review. Failures are returned to the implementer for correction.

## Previous steps

→ [/breakdown documentation](breakdown.md)  
→ [/spec documentation](spec.md)
