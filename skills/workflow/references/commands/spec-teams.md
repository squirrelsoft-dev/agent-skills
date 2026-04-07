---
description: 'Generate detailed specs from a domain-based task breakdown using agent teams'
---

# Spec Generator (Team)

Generate detailed specification files from a domain-based task breakdown using a coordinated agent team. Each teammate generates specs for their domain and can coordinate on cross-domain interfaces.

**Input**: `$ARGUMENTS` is the name of a task file (maps to `.claude/tasks/$ARGUMENTS.md`).

## Workflow

### 1. Read and validate

Read the task list file from `.claude/tasks/$ARGUMENTS.md`. If it doesn't exist, tell the user and suggest running `/breakdown $ARGUMENTS` first.

Verify the file uses **combined group+domain format** — it should contain `## Group N —` headers with `### Domain:` subsections. If it contains only `## Domain:` headers without group wrappers, tell the user: "This task file uses the old domain-only format. Please re-run `/breakdown $ARGUMENTS` to generate the updated format." and stop. If it contains `## Group N —` headers without `### Domain:` subsections, tell the user: "This task file uses group format without domains. Use `/spec` instead." and stop.

Parse the file to extract:
- Each group's number, label, and dependencies
- Each domain within each group, with agent name and owned files
- All tasks within each domain (items matching `- [ ] **Task title**`)
- The Shared Files table (if present)

### 2. Create output directory

Create `.claude/specs/$ARGUMENTS/` if it doesn't exist.

### 3. Create the team

```
TeamCreate({
  team_name: "spec-$ARGUMENTS",
  description: "Generating specs for $ARGUMENTS"
})
```

### 4. Create tasks and spawn teammates

For each domain in the task file:

1. Call `TaskCreate` with:
   - `subject`: `Generate specs for domain: <domain-label>`
   - `description`: List of all tasks in the domain with their descriptions, files, and coordination points

2. Spawn a teammate via `Agent`:
   ```
   Agent({
     team_name: "spec-$ARGUMENTS",
     name: "spec-<domain-label>",
     subagent_type: "general-purpose",
     prompt: <see Teammate Prompt below>
   })
   ```

3. Call `TaskUpdate` to assign the task to the teammate (`owner: "spec-<domain-label>"`)

### 5. Teammate Prompt

Each teammate receives:

```
You are a spec-writing agent for the "<domain-label>" domain.

Team: spec-$ARGUMENTS
Your name: spec-<domain-label>

## Your Domain

Files owned: <files owned list>

## Tasks to Spec

<for each task in this domain:>
- **<Task title>** [<size>] [order: <N>]
  <task description>
  Files: <file list>
  Coordinates with: <cross-domain refs>
  Depends on: <within-domain deps>

## Shared Files

<the full Shared Files table from the breakdown>

## Instructions

For each task in your domain:

1. Read the files listed in the task to understand existing code
2. If the task involves an unfamiliar library or pattern, note it in the spec and suggest the user run `/find-skills <topic>` to check for relevant community skills before implementation.
3. Write a spec file to `.claude/specs/$ARGUMENTS/<task-title-kebab>.md` using the format below

After writing all specs, mark your task as completed via TaskUpdate and send a message to the orchestrator confirming completion.

## Spec File Format

# Spec: <Task Title>

> From: .claude/tasks/$ARGUMENTS.md
> Domain: <domain-label>

## Objective

<What this task accomplishes and why>

## Current State

<Relevant existing code/architecture — read the listed files>

## Requirements

- <Specific, testable requirements>

## Implementation Details

- Files to create/modify with descriptions of changes
- Key functions/types/interfaces to add
- Integration points with existing code

## Dependencies

- Depends on (within domain): <tasks that must complete first>
- Coordinates with (cross-domain): <tasks in other domains this interfaces with>

## Coordination Points

- **Shared interface with <other-domain>**: <description of the interface contract>
- **Shared file strategy**: <how to handle shared files per the Shared Files table>

## Risks & Edge Cases

- <Potential issues and mitigations>

## Verification

- <How to confirm this task is done correctly>
```

### 6. Wait for completion

Wait for all teammates to complete their tasks. Monitor via messages received from teammates.

### 7. Coordination review

After all teammates finish:

1. Read all generated spec files from `.claude/specs/$ARGUMENTS/`
2. Check for consistency at coordination points:
   - Do specs that reference the same shared file agree on the interface contract?
   - Do cross-domain `Coordinates with:` references align on both sides?
3. If inconsistencies are found, send `SendMessage` to affected teammates with specific issues to revise
4. Wait for revisions to complete

### 8. Cleanup

1. Send `SendMessage({ type: "shutdown_request" })` to all teammates
2. Call `TeamDelete`
3. List all generated spec files for the user

## Rules

- Do NOT implement any code — only produce spec files
- Each spec must be grounded in the actual codebase (agents must read the listed files)
- Use kebab-case for spec filenames derived from task titles
- After all specs are written, print a summary of all generated files
