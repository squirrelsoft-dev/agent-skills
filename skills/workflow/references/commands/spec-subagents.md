---
description: 'Generate detailed specs from a task breakdown'
---

# Spec Generator

Generate detailed specification files from a task breakdown.

**Input**: `$ARGUMENTS` is the name of a task file (maps to `.workflow/tasks/$ARGUMENTS.md`).

## Workflow

1. Read the task list file from `.workflow/tasks/$ARGUMENTS.md`. If it doesn't exist, tell the user and suggest running `/breakdown $ARGUMENTS` first.
2. Check the file format — if the file contains `## Domain:` headers instead of `## Group N —` headers, tell the user: "This task file uses domain format. Use `/spec $ARGUMENTS` instead." and stop.
3. Parse all tasks — items matching the pattern `- [ ] **Task title**`.
4. Create the output directory `.workflow/specs/$ARGUMENTS/`.
5. For each task, spawn a subagent using the `Agent` tool in parallel. Use `run_in_background: true` so all agents run concurrently. Do **not** use `isolation: "worktree"` — spec agents only read code and write to `.workflow/specs/`, so they won't conflict.
6. Each agent receives:
   - The task title
   - The task description (lines following the checkbox until the next task)
   - The listed files
   - Dependency info (Blocked by / Blocking)
   - The full path to write its spec file: `.workflow/specs/$ARGUMENTS/{task-title-kebab}.md`
7. Each agent must:
   - Read the files listed in the task to understand existing code
   - If the task involves an unfamiliar library or pattern, note it in the spec under Implementation Details and suggest the user run `/find-skills <topic>` to check for relevant community skills before implementation.
   - Write a spec file to `.workflow/specs/$ARGUMENTS/{task-title-kebab}.md` using the format below
8. After all agents complete, list the generated spec files for the user.

## Spec File Format

Each agent should produce a file with this exact structure:

```markdown
# Spec: <Task Title>

> From: .workflow/tasks/{name}.md

## Objective

<What this task accomplishes and why>

## Current State

<Relevant existing code/architecture — agent reads the listed files>

## Requirements

- <Specific, testable requirements>

## Implementation Details

- Files to create/modify with descriptions of changes
- Key functions/types/interfaces to add
- Integration points with existing code

## Dependencies

- Blocked by: <tasks that must complete first>
- Blocking: <tasks that depend on this>

## Risks & Edge Cases

- <Potential issues and mitigations>

## Verification

- <How to confirm this task is done correctly>
```

## Rules

- Do NOT implement any code — only produce spec files
- Each spec must be grounded in the actual codebase (agents must read the listed files)
- Use kebab-case for spec filenames derived from task titles
- After all specs are written, print a summary of all generated files
