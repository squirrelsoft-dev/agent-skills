---
description: 'Implement a task list one task at a time using a tight implement → review → commit loop'
---

# Work (Team)

Implement a task list by processing each incomplete task sequentially: spawn an implementer, run fast quality gates on the diff, commit as a checkpoint, then move on. After all tasks in a group complete, run a full 8-gate quality pass. The main agent never reads spec files or source files — it only tracks state and orchestrates agents.

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

  Verify the file uses **combined group+domain format** — it should contain `## Group N —` headers with `### Domain:` subsections. If it contains only `## Domain:` headers without group wrappers, tell the user: "This task file uses the old domain-only format. Please re-run `/breakdown $ARGUMENTS` to generate the updated format." and stop.

  Parse the file to extract:

- Each group's number, label, and dependencies

- Each domain within each group, with agent name and owned files

- All tasks within each domain with their spec paths (`.claude/specs/$ARGUMENTS/<task-title-kebab>.md`)

### 2. Verify specs exist

Check that `.claude/specs/$ARGUMENTS/` contains a spec file for every incomplete task (`- [ ]`). For each incomplete task, look for `.claude/specs/$ARGUMENTS/<task-title-kebab>.md`.

If any specs are missing, list them and suggest running `/spec $ARGUMENTS` first. Stop.

### 3. Setup

1. **Disable stop hooks** — create a flag file so the stop-quality-gate hook skips during the workflow run:

   ```bash
   touch .claude/.workflow-running
   ```

2. **Create or switch to the feature branch**:

   ```bash
   git checkout -b feat/$ARGUMENTS 2>/dev/null || git checkout feat/$ARGUMENTS
   ```

3. **Create the team**:

   ```
   TeamCreate({ team_name: "work-$ARGUMENTS" })
   ```

4. Print the queue:

```
Work: $ARGUMENTS
──────────────────────────
Feature branch: feat/$ARGUMENTS

Groups:
  [queued] Group 1 — <label>  (<N> tasks)
  [queued] Group 2 — <label>  (<N> tasks)
  ...
  [complete] Group N — <label>  (skipped)
──────────────────────────
```

### 4. Process groups

For each group in dependency order (respecting `_Depends on: Group N_` declarations):

#### 4a. Process each task sequentially

Collect all incomplete tasks (`- [ ]`) in this group, in the order they appear in the task file. For each task:

---

**Step i — Implement**

Spawn a fresh implementer agent:

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "impl",
  agent: "domain-implementer",
  mode: "acceptEdits",
  prompt: `
    You are an implementer agent on branch feat/$ARGUMENTS.

    ## Your Task
    Title: <task title>
    Spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
    Domain: <domain-label>
    Files owned: <files owned for this domain>

    ## Instructions
    1. Read the spec file at the path above
    2. Read any existing source files listed in the spec
    3. Implement the spec exactly
    4. Do NOT commit
    5. Do NOT push
    6. When done, send TASK_COMPLETE to main:
       TASK_COMPLETE
       task: <task title>
       status: success | failed
       notes: <one-line summary or "none">
       TASK_COMPLETE_END
  `
})
```

Wait for `TASK_COMPLETE` from `impl`.

If `status: failed`:

- Ask the user: "Task `<title>` failed: `<notes>`. Skip and continue, retry, or stop?"

- Handle response before proceeding

  Shut down the implementer:

```
SendMessage({ to: "impl", message: "shutdown" })
```

---

**Step ii — Fast quality gates**

Spawn a quality agent scoped to the diff only:

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "quality",
  agent: "quality",
  mode: "acceptEdits",
  prompt: `
    You are the quality agent.
    Branch: feat/$ARGUMENTS
    Task: <task title>
    Spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
    logDir: .claude/quality/$ARGUMENTS/task-<kebab-title>/

    Run ONLY these gates on the uncommitted diff (git diff HEAD):
      Gate 1 — Lint (lintCmd: <lintCmd or empty>)
      Gate 2 — Typecheck (typecheckCmd: <typecheckCmd or empty>)
      Gate 6 — Review (spec-aware code review)

    Skip Gates 3, 4, 5, 7, 8 — these run in the full group pass later.

    Auto-remediate issues up to 3 attempts per gate.
    Send FAST_QA_REPORT when complete:
      FAST_QA_REPORT
      task: <task title>
      gate_lint: PASS | FAIL | SKIPPED
      gate_typecheck: PASS | FAIL | SKIPPED
      gate_review: PASS | FAIL
      overall: PASS | FAIL
      notes: <one-line summary or "none">
      FAST_QA_REPORT_END
  `
})
```

Wait for `FAST_QA_REPORT`.

Display progress:

```
  [task] <title>
    lint:       PASS | FAIL | SKIPPED
    typecheck:  PASS | FAIL | SKIPPED
    review:     PASS | FAIL
```

If `overall: FAIL`:

- Ask the user: "Fast QA failed on `<title>` (<failed gates>). Commit anyway, skip task, or stop?"

- Handle response

  Shut down the quality agent:

```
SendMessage({ to: "quality", message: "shutdown" })
```

---

**Step iii — Commit checkpoint**

Spawn a fresh git-expert for this commit only:

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "git-expert",
  agent: "git-expert",
  mode: "acceptEdits",
  prompt: `
    You are the git-expert for feat/$ARGUMENTS.
    Execute this single COMMIT operation, report GIT_COMMIT_COMPLETE, then stop.
    Do NOT push. Do NOT modify history.

    Operation: COMMIT
    branch: feat/$ARGUMENTS
    message: feat(<domain>): <task title>
    taskListFile: .claude/tasks/$ARGUMENTS.md
    taskTitle: <task title>
  `
})
```

Wait for `GIT_COMMIT_COMPLETE`, then immediately shut down:

```
SendMessage({ to: "git-expert", message: "shutdown" })
```

Print:

```
  ✓ <task title>  (checkpoint committed)
```

---

Repeat steps i–iii for the next task in the group.

#### 4b. Full group quality pass

After all tasks in the group are committed, spawn a fresh quality agent for the full 8-gate pass:

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "quality-full",
  agent: "quality",
  mode: "acceptEdits",
  prompt: `
    You are the quality agent running a full group pass.
    Branch: feat/$ARGUMENTS
    Task: Group <N> — <label> (full pass)
    logDir: .claude/quality/$ARGUMENTS/group-<N>/
    lintCmd: <lintCmd or empty>
    typecheckCmd: <typecheckCmd or empty>
    buildCmd: <buildCmd or empty>
    testCmd: <testCmd or empty>

    Run ALL 8 gates on the current branch state.
    Auto-remediate up to 3 attempts per gate.
    Send QUALITY_GATE_REPORT when complete.
  `
})
```

Wait for `QUALITY_GATE_REPORT`.

Display:

```
  [group pass] Group <N> — <label>
    lint:            PASS | FAIL | SKIPPED
    typecheck:       PASS | FAIL | SKIPPED
    build:           PASS | FAIL | SKIPPED
    test:            PASS | FAIL | SKIPPED
    simplify:        PASS | FAIL
    review:          PASS | FAIL
    security-review: PASS | FAIL
    security-scan:   PASS | FAIL
```

If `overall: FAIL`:

- Ask the user: "Full group QA failed (<failed gates>). Accept and continue, or stop?"

- If stop, proceed to cleanup and halt

  Verify QA logs:

```bash
ls .claude/quality/$ARGUMENTS/group-<N>/gate-*.log 2>/dev/null | wc -l
```

If fewer than 8, warn the user.

Shut down quality-full:

```
SendMessage({ to: "quality-full", message: "shutdown" })
```

Print group summary:

```
──────────────────────────
✓ Group <N> — <label> complete
  Tasks: <N> committed
  QA logs: .claude/quality/$ARGUMENTS/group-<N>/
  Next: Group <M> — <label>   (or "All groups complete")
──────────────────────────
```

If `--all` flag is set and more groups remain, loop back to step 4 for the next group.

### 5. Cleanup

1. **Delete the team**:

   ```
   TeamDelete({ team_name: "work-$ARGUMENTS" })
   ```

2. **Re-enable stop hooks**:

   ```bash
   rm -f .claude/.workflow-running
   ```

3. **Print final summary**:

```
══════════════════════════════════
  Work Complete: $ARGUMENTS
══════════════════════════════════

Feature branch: feat/$ARGUMENTS

Groups completed this session:
  ✓ Group 1 — <label>  (<N> tasks, QA: PASS)
  ✓ Group 2 — <label>  (<N> tasks, QA: PASS)

Previously complete (skipped):
  ✓ Group N — <label>

Still incomplete (if any):
  ✗ Group M — <label>  (<reason>)

Next steps:
  Review the feature branch and run /squash-pr $ARGUMENTS
══════════════════════════════════
```

---

## git-expert COMMIT operation

Add this operation to the git-expert agent. When it receives a COMMIT message:

1. Stage all changes:

   ```bash
   git add -A
   ```

2. Commit with the provided message:

   ```bash
   git commit -m "<message>"
   ```

3. Mark the task complete in the task list file:
   - Read `<taskListFile>`
   - Find `- [ ] **<taskTitle>**` and replace with `- [x] **<taskTitle>**`
   - Write back and verify

4. Respond:

   ```
   GIT_COMMIT_COMPLETE
   task: <taskTitle>
   sha: <short sha>
   GIT_COMMIT_COMPLETE_END
   ```

---

## Error handling

- **Implementer not responding**: Warn the user, offer to retry or skip the task
- **Fast QA unresolvable**: User decides per task — skip, commit anyway, or stop
- **Full group QA unresolvable**: User decides per group — accept or stop
- **Blocked groups** (in `--all` mode): If a group's dependencies are unmet, report and stop

## Rules

- Do NOT read spec files — pass spec paths to agents, let them read
- Do NOT read source files — implementers own that
- Do NOT implement anything directly — delegate to impl agents
- Do NOT run quality gates directly — delegate to quality agents
- Do NOT commit directly — delegate to git-expert
- DO process tasks sequentially within a group
- DO process groups sequentially in dependency order
- DO shut down each agent immediately after it completes
- DO keep main agent context minimal — only TASK_COMPLETE, FAST_QA_REPORT, QUALITY_GATE_REPORT, and GIT_COMMIT_COMPLETE flow back
