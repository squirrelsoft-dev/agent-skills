---
description: 'Break a high-level task into subtasks organized by domain ownership for agent teams'
---

# Task Breakdown (Team)

Spawn a general-purpose agent to break down the following task: `$ARGUMENTS`

**Important** — This agent does not produce code or create any output other than generating the complete tasks file. The output is organized by **domain** (area of the codebase) rather than dependency groups, so that each agent in a team can own a non-overlapping slice of files.

## Mode Detection

Parse `$ARGUMENTS` to determine the mode:

- **GitHub Issue mode**: If `--issue` flag is present (e.g., `/breakdown 7 --issue` or `/breakdown #42 --issue`), extract the issue number and fetch the full issue context from GitHub before breaking it down.
- **Freeform mode** (default): If no `--issue` flag, treat the arguments as a plain task description.

## GitHub Issue Mode

When `--issue` is detected:

1. **Fetch the issue** — Run `gh issue view <number> --json number,title,body,labels,assignees,milestone,comments` to get the full issue including all comments.
2. **Parse the context** — Read through the issue title, body, labels, and all comments (including any triage comments with implementation plans). Comments often contain valuable context like implementation approaches, architectural decisions, and caveats identified during triage.
3. **Ask clarifying questions** — If the issue body or comments leave ambiguity about scope, acceptance criteria, or approach, ask the user for clarification before proceeding with the breakdown. Do not guess — ask.
4. **Proceed with the breakdown** using the full issue context as the task description.

When saving the task file in issue mode, use the format `.claude/tasks/issue-<number>.md` (e.g., `.claude/tasks/issue-7.md`).

## Breakdown Steps

The agent should:

1. **Understand** — Restate the task. Ask clarifying questions if the scope is ambiguous.
2. **Research** — Read relevant files to understand the codebase, architecture, and existing patterns.
3. **Find relevant skills** — Search for community skills that may help with the task or its subtasks. Run `npx skills find <topic>` for key technologies or patterns involved. If a relevant skill is found, run `npx skills add <owner/repo@skill>` to install it. Installed skills will be available to all agents during implementation.
4. **Decompose** — Break the task into the smallest meaningful units of work.
5. **Identify file ownership** — For each task, list ALL files it will create or modify.
6. **Cluster into domains** — Group tasks by the area of the codebase they touch. Use these guidelines:
   - Infer domain names from the actual project structure (e.g., `ui`, `api`, `data`, `lib`, `config`)
   - Target **2–5 domains**. If more than 5 emerge, merge the smallest domains together.
   - Each domain should map to a distinct set of directories/files with minimal overlap.
   - Common domain patterns: frontend components/styles, backend routes/controllers, database models/migrations, shared packages/utilities, configuration/infrastructure.
7. **Handle cross-domain tasks** — If a task touches files in multiple domains:
   - If one domain is primary (80%+ of the files), assign it there and add a `Coordinates with:` note referencing the other domain's tasks.
   - If truly split across domains, break the task into two sub-tasks, one per domain.
8. **Order within domains** — Within each domain, number tasks in the order they should be executed. Tasks may depend on earlier tasks within the same domain.
9. **Identify shared files** — Files that appear in multiple domains must be listed in a Shared Files table with an explicit resolution strategy (who writes first, what contract to follow).
10. **Save** — Create the `.claude/tasks/` directory if needed, then write the breakdown to the appropriate file:
    - Issue mode: `.claude/tasks/issue-<number>.md`
    - Freeform mode: `.claude/tasks/<kebab-cased-arguments>.md`

## Output Format

```markdown
# Task Breakdown: <feature name>

> <one-sentence summary>

## Domain: <domain-label> (Agent: <agent-name>)

_Files owned: `src/components/`, `src/styles/`, `public/`_

- [ ] **Task title** `[S/M/L]` `[order: 1]`
      <what to do and why>
      Files: `path/to/file`
      Coordinates with: <task titles in other domains, or "None">

- [ ] **Task title** `[S/M/L]` `[order: 2]`
      <what to do and why>
      Files: `path/to/file`
      Depends on: <earlier task title within this domain>
      Coordinates with: None

## Domain: <domain-label> (Agent: <agent-name>)

_Files owned: `src/api/`, `src/middleware/`_

- [ ] **Task title** `[S/M/L]` `[order: 1]`
      <what to do and why>
      Files: `path/to/file`
      Coordinates with: <task titles in other domains, or "None">

## Shared Files

_These files are touched by multiple domains. Coordination required._

| File                 | Domains | Strategy                                |
| -------------------- | ------- | --------------------------------------- |
| `src/types/index.ts` | ui, api | api writes interface; ui consumes after |
| `package.json`       | ui, lib | lib adds deps first; ui adds after      |
```

## Format Rules

- **`## Domain:` sections** — One per domain. Each has a suggested agent name (e.g., `impl-ui`, `impl-api`).
- **`Files owned:`** — Declares the directory/file scope for the domain. This becomes the agent's territory during implementation.
- **`[order: N]`** — Sequential execution order within the domain.
- **`Coordinates with:`** — Soft cross-domain reference. Means "these tasks should be aware of each other" — not a hard block.
- **`Depends on:`** — Hard dependency on an earlier task **within the same domain only**.
- **`Shared Files` table** — Every file that appears in more than one domain's task list. The Strategy column says who writes first and what contract to follow.
- Domains run **fully in parallel**. There is no inter-domain blocking (except prerequisite domains — see below).

## Edge Cases

- **Prerequisite domain**: If a domain produces shared artifacts that all other domains need (e.g., shared types, database schema), mark it with `[prerequisite]` after the domain label. Prerequisite domains must complete before other domains start.
  ```markdown
  ## Domain: types (Agent: impl-types) [prerequisite]
  ```
- **Single-domain project**: If all tasks touch the same area of the codebase, tell the user and suggest using `/breakdown` + `/work` instead, since team-based splitting provides no benefit.
- **Too many domains**: If more than 5 domains emerge, merge the smallest ones until ≤ 5.

## Rules

- Complexity: `S` (< 30 min), `M` (30 min–2 hrs), `L` (2+ hrs)
- Do NOT implement anything — only produce the task file
- After saving, print the full task list for the user to review
