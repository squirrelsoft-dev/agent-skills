# /breakdown

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/breakdown.md`  
**Requires:** architect agent

Decomposes a feature description into a structured list of implementation tasks. The starting point of the `/breakdown` → `/spec` → `/work` development loop.

## Usage

```
/breakdown <feature-name-or-description>
```

## What it does

Spawns the architect agent to analyze the request against the existing codebase and produce a task breakdown. The breakdown identifies affected areas, dependencies between tasks, and recommended implementation order.

## Output

A task list saved to `.claude/tasks/<feature>.md`, structured for consumption by `/spec`.

## Orchestration modes

Two variants are installed depending on the mode chosen during `/workflow`:

**Subagents** — the architect runs as a subagent in an isolated worktree, then the task list is returned to the main session.

**Agent teams** — the architect produces a combined group+domain format with `## Group N —` headers containing `### Domain:` subsections, organizing tasks into sequential groups for group-based execution.

## Next step

```
/spec <feature-name>
```

→ [/spec documentation](spec.md)
