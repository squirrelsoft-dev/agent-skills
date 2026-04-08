---
description: 'Implement a group-based task breakdown using a coordinated agent team'
---

# Work (Team)

Orchestrate implementation of a group-based task breakdown by spawning a team of domain-implementer agents. Each agent owns a non-overlapping slice of the codebase. Work progresses one group at a time: teammates implement → Quality Gate agent verifies → next group. After all groups: single commit.

**Input:** `$ARGUMENTS` — task list name, optionally followed by `--all`

- `work <task-name>` — implement the next available group only
- `work <task-name> --all` — implement every incomplete group in dependency order

---

## Steps

### 1. Parse and validate

Split `$ARGUMENTS` on whitespace. Extract:
- `taskListName` — first token (e.g. `issue-3`)
- `allFlag` — true if `--all` is present

Read `.claude/tasks/$ARGUMENTS.md`. If it doesn't exist, tell the user and stop.

Verify the file uses **combined group+domain format** — it should contain `## Group N —` headers with `### Domain:` subsections. If it contains only `## Domain:` headers without group wrappers, tell the user: "This task file uses the old domain-only format. Please re-run `/breakdown $ARGUMENTS` to generate the updated format." and stop. If it contains `## Group N —` headers without `### Domain:` subsections, tell the user: "This task file uses group format. Use `/work` instead." and stop.

Parse the file to extract:
- Each group's number, label, and dependencies
- Each domain within each group, with agent name and owned files
- All tasks within each domain with their descriptions and coordination points
- The Shared Files table

### 2. Verify specs exist

Check that `.claude/specs/$ARGUMENTS/` contains a spec file for every incomplete task (`- [ ]`). For each incomplete task, look for `.claude/specs/$ARGUMENTS/<task-title-kebab>.md`.

If any specs are missing, list them and suggest running `/spec $ARGUMENTS` first. Stop.

### 3. Setup

1. **Create the feature branch** from current HEAD:
   ```bash
   git checkout -b feat/$ARGUMENTS
   ```
   If the branch already exists, switch to it:
   ```bash
   git checkout feat/$ARGUMENTS
   ```

2. **Create the team**:
   ```
   TeamCreate({
     team_name: "work-$ARGUMENTS",
     description: "Implementing $ARGUMENTS"
   })
   ```

3. **Create tasks** — For each incomplete group, call `TaskCreate` with:
   - `subject`: `$ARGUMENTS — Group <N>: <label>`
   - `description`: Comma-separated list of incomplete task titles in the group

4. **Set up dependencies** via `TaskUpdate`:
   - If a group has `_Depends on: Group N_`, add `addBlockedBy` on the depended group's task

5. **Identify unique domains** — Collect all unique domain labels across all groups, along with their `Files owned:` declarations.

Print the queue:
```
Work Team: $ARGUMENTS
──────────────────────────
Feature branch: feat/$ARGUMENTS

Domains:
  <domain-label>  <files owned>
  <domain-label>  <files owned>
  ...

Groups:
  [queued] Group 1 — <label>  (<N> tasks across <M> domains)
  [queued] Group 2 — <label>  (<N> tasks across <M> domains)
  ...
  [complete] Group N — <label>  (skipped)
──────────────────────────
```

### 4. Spawn teammates

Spawn one teammate per unique domain. Teammates are **persistent** — they survive across groups and receive work via `SendMessage`.

For each unique domain:

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "impl-<domain-label>",
  subagent_type: "general-purpose",
  prompt: `
    You are a domain-implementer agent.

    Team: work-$ARGUMENTS
    Your name: impl-<domain-label>
    Domain: <domain-label>
    Feature branch: feat/$ARGUMENTS

    ## File Ownership

    You may ONLY modify files within these paths:
    <files owned list>

    Do NOT touch any files outside this scope.

    ## Shared Files

    <full Shared Files table>

    ## Instructions

    Wait for group assignment messages. For each GROUP_ASSIGNMENT message you receive:
    1. Parse the tasks and spec file paths
    2. For each task, read the spec file and implement it
    3. When all your group tasks are done, send GROUP_COMPLETE
    4. Wait for the next group assignment or shutdown signal

    For each GROUP_ASSIGNMENT, after completing all tasks, send exactly:
      GROUP_COMPLETE
      domain: <domain-label>
      group: <N>
      tasksCompleted: <count>
      issues: <summary or "none">
      GROUP_COMPLETE_END

    ## Critical Rules

    - NEVER modify files outside your owned paths
    - Do NOT commit — leave changes uncommitted
    - Do NOT push or run destructive git commands
    - For shared files, follow the Strategy column in the Shared Files table
    - Follow specs exactly; if ambiguous, make the conservative choice and note it
    - Read existing code before writing new code
    - Do NOT send progress messages after individual tasks — only GROUP_COMPLETE
  `
})
```

### 5. Process groups

For each group in dependency order:

#### 5a. Assign group tasks to teammates

For each domain that has tasks in this group, send a `SendMessage`:

```
SendMessage({
  to: "impl-<domain-label>",
  message: `
    GROUP_ASSIGNMENT
    group: <N>
    tasks:
      - title: <task title>
        spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
      - title: <task title>
        spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
    GROUP_ASSIGNMENT_END
  `
})
```

Send to all relevant domains in parallel. If a domain has no tasks in this group, do not message it.

Print:
```
Group <N> — <label>: assigning to <domain-list>
```

#### 5b. Wait for GROUP_COMPLETE

Wait for a `GROUP_COMPLETE` message from each domain that was assigned tasks in this group. As each arrives, print:

```
[impl-<domain>] ✓ Group <N> complete (<M> tasks)
```

If a teammate reports issues in its `GROUP_COMPLETE` message, print the issues and ask the user via `AskUserQuestion`:
- `"Continue with quality gates"` — proceed to 5c
- `"Stop"` — shut down all teammates and stop

#### 5c. Spawn Quality Gate agent

Spawn the **Quality agent** defined at `.claude/agents/quality.md` (NOT a teammate — a foreground subagent). This agent absorbs all retry context, keeping the main agent's context minimal. Do NOT run quality gates yourself — always delegate to this agent.

```
Agent({
  agent: "quality",
  run_in_background: false,
  prompt: `
    branch: feat/$ARGUMENTS
    taskTitle: Group <N> — <label>
    specFile: .claude/specs/$ARGUMENTS/
    lintCmd: <project lint command>
    typecheckCmd: <project typecheck command>
    buildCmd: <project build command>
    testCmd: <project test command>
  `
})
```

The agent will return a `QUALITY_GATE_REPORT_START ... QUALITY_GATE_REPORT_END` block with results for all 8 gates.

#### 5d. Handle QA results

Parse the `QUALITY_GATE_REPORT_START ... QUALITY_GATE_REPORT_END` block. Show results:

```
QA Results — Group <N>: <label>
  Lint             [PASS|FAIL]
  Typecheck        [PASS|FAIL]
  Build            [PASS|FAIL]
  Test             [PASS|FAIL]
  Simplify         [PASS|FAIL]
  Review           [PASS|FAIL]
  Security Review  [PASS|FAIL]
  Security Scan    [PASS|FAIL]
  Overall: [PASS|FAIL]
```

If overall **PASS**:
1. Mark the group's task entry complete via `TaskUpdate(status: completed)`. The `TaskCompleted` hook fires (format + task-summary on clean code).
2. **Update the task file immediately** — Read `.claude/tasks/$ARGUMENTS.md` and flip `- [ ]` to `- [x]` for every task in this group. This ensures progress is persisted even if the session is interrupted before step 6.

If overall **FAIL**, ask via `AskUserQuestion`:
- `"Accept and continue"` ⚠️
- `"Stop"` 🛑

#### 5e. Loop

If `--all` flag is set, continue to the next available group. Otherwise stop after this group.

Print group progress:
```
──────────────────────────
✓ Group <N> — <label> complete
  Next: Group <M> — <label>   (or "All groups complete")
──────────────────────────
```

### 6. Commit and cleanup

1. **Stage all changes**:
   ```bash
   git add -A
   ```

2. **Create a single commit** on the feature branch:
   ```bash
   git commit -m "feat: <task list title from the # heading>"
   ```

3. **Shutdown teammates**:
   ```
   SendMessage({ to: "*", message: { type: "shutdown_request" } })
   ```

4. **Delete the team**:
   ```
   TeamDelete()
   ```

5. **Print final summary**:

```
══════════════════════════════════
  Team Work Complete: $ARGUMENTS
══════════════════════════════════

Feature branch: feat/$ARGUMENTS

Groups completed this session:
  ✓ Group 1 — <label>  (QA: PASS)
  ✓ Group 2 — <label>  (QA: PASS)

Previously complete (skipped):
  ✓ Group N — <label>

Still incomplete (if any):
  ✗ Group M — <label>  (<reason>)

Domains:
  impl-ui:     <N> tasks across <M> groups
  impl-api:    <N> tasks across <M> groups

Commit: <short sha> feat: <title>

Next steps:
  Review the feature branch and open a PR.
══════════════════════════════════
```

---

## Error handling

- **Teammate failure**: warn user, offer continue-with-quality-gates or stop
- **Quality Gate failure**: offer accept or stop
- **Blocked groups** (in `--all` mode): if a group's dependencies are unmet after prior groups complete, report blockage and stop

## Rules

- Do NOT implement anything directly — always delegate to domain-implementer teammates
- Do NOT commit until all quality gates pass for completed groups
- Do NOT skip the Quality Gate phase — every group must pass through quality gates
- Do NOT run quality gates yourself — ALWAYS spawn the Quality agent via `agent: "quality"` (step 5c). The main agent never runs lint, typecheck, build, test, simplify, review, or any other gate directly.
- Do NOT inline a custom quality gate prompt — use `agent: "quality"` which references `.claude/agents/quality.md`. Pass only the input variables (branch, taskTitle, specFile, lintCmd, typecheckCmd, buildCmd, testCmd).
- Do NOT process groups in parallel — dependency order must be respected
- DO spawn all domain teammates upfront — they persist across groups
- DO send group assignments only to domains that have tasks in that group
- DO keep main agent context minimal — Quality Gate agent absorbs all retry context
