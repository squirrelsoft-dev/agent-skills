---
description: 'Implement a task list one spec at a time using a tight Planner → Executor → Evaluator loop, then run full quality gates once at the end'
---

# Work (Loop)

Implement a task list spec-by-spec using a **Planner → Executor → Evaluator** loop. For each spec the planner produces a plan, the executor implements it, and the evaluator runs mini-QA plus spec-compliance review. If the evaluator fails, the main agent asks the planner to replan (up to 2 iterations per spec) before escalating to the user. Once every spec is committed, a single full 8-gate quality pass runs at the end with auto-remediation. The main agent never reads spec files or source files — it only tracks state and orchestrates agents.

This mode is optimized for **spec-compliance correctness**, not raw speed. It catches cases where the implementation is "wrong per spec" (not just failing gates) that other `/work` modes silently commit.

**Input:** `$ARGUMENTS` — task list name, optionally followed by `--all` and/or `--mode <permission-mode>`

- `work <task-name>` — process every incomplete spec in the task list (this mode is sequential; `--all` is implied)
- `work <task-name> --all` — same as above, explicit
- `work <task-name> --mode auto` — spawn all teammates in `auto` permission mode
- `work <task-name> --mode bypassPermissions` — spawn all teammates in `bypassPermissions` mode (use with caution)
- Flags can be combined: `work <task-name> --all --mode auto`

---

## Steps

### 1. Parse and validate

Split `$ARGUMENTS` on whitespace. Extract:

- `taskListName` — first non-flag token (e.g. `issue-3`)
- `allFlag` — true if `--all` is present (loop mode treats this as always true, but accept the flag for parity with other modes)
- `permissionMode` — value following `--mode` if present. Allowed values: `default`, `acceptEdits`, `auto`, `bypassPermissions`. If `--mode` is not provided, default to `acceptEdits`. If an invalid value is supplied, tell the user and stop.

Read `.workflow/tasks/$ARGUMENTS.md`. If it doesn't exist, tell the user and stop.

Parse the file to extract, in dependency order:
- Each group's number, label, and `_Depends on: Group N_` declarations
- All incomplete tasks (`- [ ]`) within each group, with their spec paths (`.workflow/specs/$ARGUMENTS/<task-title-kebab>.md`)

**Flatten** the groups into a single ordered spec queue. Loop mode runs strictly sequentially — there is no parallelism within a group. Group ordering still governs dependency order.

### 2. Verify specs exist

Check that `.workflow/specs/$ARGUMENTS/` contains a spec file for every incomplete task. For each incomplete task, look for `.workflow/specs/$ARGUMENTS/<task-title-kebab>.md`.

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

4. **Spawn the planner ONCE** (persistent across the entire task):

   ```
   Agent({
     team_name: "work-$ARGUMENTS",
     name: "planner",
     agent: "planner",
     mode: "<permissionMode>",
     prompt: `
       You are the planner for feat/$ARGUMENTS.
       You will receive PLAN_REQUEST and REPLAN messages from the main agent
       for each spec in this task, one at a time.
       Maintain your running summary of completed specs across messages.
       Follow the planner.md protocol exactly.
     `
   })
   ```

5. Print the queue:

```
Work (loop): $ARGUMENTS
──────────────────────────
Feature branch: feat/$ARGUMENTS
Planner: opus (persistent)

Spec queue:
  [queued] <spec-title-1>  (Group 1)
  [queued] <spec-title-2>  (Group 1)
  [queued] <spec-title-3>  (Group 2)
  ...
──────────────────────────
```

### 4. Process each spec

For each spec in the queue in order:

---

**Step 4a — Request plan**

Send a `PLAN_REQUEST` to the persistent planner:

```
SendMessage({
  to: "planner",
  message: `
    PLAN_REQUEST
    specPath: .workflow/specs/$ARGUMENTS/<kebab>.md
    iteration: 1
    PLAN_REQUEST_END
  `
})
```

Wait for a `PLAN` message from the planner. Capture the full `PLAN` block — you will pass it verbatim to the executor and the evaluator.

---

**Step 4b — Execute plan**

Spawn a fresh executor agent (ephemeral per spec):

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "executor",
  agent: "executor",
  mode: "<permissionMode>",
  prompt: `
    You are the executor on branch feat/$ARGUMENTS.

    featureBranch: feat/$ARGUMENTS
    specPath: .workflow/specs/$ARGUMENTS/<kebab>.md

    plan: |
      <PASTE THE PLAN BLOCK FROM STEP 4a VERBATIM>

    Follow executor.md. Implement the plan, do NOT commit, then send
    EXECUTION_COMPLETE.
  `
})
```

Wait for `EXECUTION_COMPLETE` from `executor`.

If `status: blocked`:
- Ask the user via `AskUserQuestion`: "Executor blocked on `<spec-title>`: `<notes>`. Skip spec, retry, or stop?"
- Handle response:
  - **Skip**: `git checkout -- .` to discard uncommitted changes, shut down executor, continue to next spec
  - **Retry**: shut down executor and loop back to Step 4b with a fresh executor (still iteration 1)
  - **Stop**: shut down executor and proceed to Cleanup

Shut down the executor:

```
SendMessage({ to: "executor", message: "shutdown" })
```

---

**Step 4c — Evaluate**

Spawn a fresh evaluator agent (ephemeral per spec):

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "evaluator",
  agent: "evaluator",
  mode: "<permissionMode>",
  prompt: `
    You are the evaluator for feat/$ARGUMENTS.

    featureBranch: feat/$ARGUMENTS
    specPath: .workflow/specs/$ARGUMENTS/<kebab>.md
    iteration: <current iteration, 1 or 2>
    logDir: .workflow/quality/$ARGUMENTS/spec-<kebab>/iter-<N>/
    lintCmd: <lintCmd or empty>
    typecheckCmd: <typecheckCmd or empty>
    testCmd: <testCmd or empty>
    uiGlobs: <uiGlobs or empty>

    plan: |
      <PASTE THE PLAN BLOCK FROM STEP 4a VERBATIM>

    Follow evaluator.md. Do NOT modify source code. Send EVAL_REPORT when done.
  `
})
```

Wait for `EVAL_REPORT` from `evaluator`.

Display progress:

```
  [spec] <title>  iter <N>
    lint:        PASS | FAIL | SKIPPED
    typecheck:   PASS | FAIL | SKIPPED
    test:        PASS | FAIL | SKIPPED
    playwright:  PASS | FAIL | SKIPPED
    compliance:  PASS | FAIL
```

Verify the evaluator wrote its logs:

```bash
ls .workflow/quality/$ARGUMENTS/spec-<kebab>/iter-<N>/gate-*.log 2>/dev/null | wc -l
```

If zero, warn the user but continue.

Shut down the evaluator:

```
SendMessage({ to: "evaluator", message: "shutdown" })
```

---

**Step 4d — Decide**

**If `overall: PASS`:**

Proceed to Step 4e (commit).

**If `overall: FAIL` and iteration < 2:**

Send a `REPLAN` to the planner with the evaluator's findings:

```
SendMessage({
  to: "planner",
  message: `
    REPLAN
    specPath: .workflow/specs/$ARGUMENTS/<kebab>.md
    iteration: 2
    findings: |
      <PASTE THE findings BLOCK FROM THE EVAL_REPORT VERBATIM>
    REPLAN_END
  `
})
```

Wait for a new `PLAN` from the planner, then loop back to Step 4b with iteration = 2. (Do NOT discard the executor's previous changes — the replan will edit them in place.)

**If `overall: FAIL` and iteration == 2:**

Ask the user via `AskUserQuestion`: "Spec `<title>` failed evaluation twice. Findings: `<one-line summary>`. Commit anyway, skip spec, or stop?"

- **Commit anyway**: proceed to Step 4e
- **Skip spec**: `git checkout -- .` to discard uncommitted changes, continue to next spec (do NOT mark the task complete in the task file)
- **Stop**: proceed to Cleanup

---

**Step 4e — Commit checkpoint**

Spawn a fresh git-expert for this commit only:

```
Agent({
  team_name: "work-$ARGUMENTS",
  name: "git-expert",
  agent: "git-expert",
  mode: "<permissionMode>",
  prompt: `
    You are the git-expert for feat/$ARGUMENTS.
    Execute this single COMMIT operation, report GIT_COMMIT_COMPLETE, then stop.
    Do NOT push. Do NOT modify history.

    Operation: COMMIT
    branch: feat/$ARGUMENTS
    message: feat: <spec title>
    taskListFile: .workflow/tasks/$ARGUMENTS.md
    taskTitle: <spec title>
  `
})
```

Wait for `GIT_COMMIT_COMPLETE`, then shut down:

```
SendMessage({ to: "git-expert", message: "shutdown" })
```

Print:

```
  ✓ <spec title>  (iter <N>, checkpoint committed)
```

Continue to the next spec in the queue.

---

### 5. Shut down the planner

After every spec in the queue has been processed (committed, skipped, or the user chose stop), shut down the persistent planner:

```
SendMessage({ to: "planner", message: "shutdown" })
```

### 6. Final full quality pass

If the user chose **Stop** earlier, skip this step and proceed to Cleanup.

Otherwise, run the full 8-gate quality pass once across the entire feature branch, with iterative retries until it passes or the user stops.

Initialize `qualityAttempt = 1`.

Loop:

1. Spawn a fresh quality agent:

   ```
   Agent({
     team_name: "work-$ARGUMENTS",
     name: "quality-final",
     agent: "quality",
     model: "sonnet",
     mode: "<permissionMode>",
     prompt: `
       You are the quality agent running the final full pass for the loop mode.
       Branch: feat/$ARGUMENTS
       Task: $ARGUMENTS (final pass, attempt <qualityAttempt>)
       logDir: .workflow/quality/$ARGUMENTS/final/attempt-<qualityAttempt>/
       lintCmd: <lintCmd or empty>
       typecheckCmd: <typecheckCmd or empty>
       buildCmd: <buildCmd or empty>
       testCmd: <testCmd or empty>

       Run ALL 8 gates on the current branch state.
       Auto-remediate each gate up to 3 attempts.
       Send QUALITY_GATE_REPORT when complete.
     `
   })
   ```

2. Wait for `QUALITY_GATE_REPORT`.

3. Display:

   ```
   [final pass — attempt <qualityAttempt>]
     lint:            PASS | FAIL | SKIPPED
     typecheck:       PASS | FAIL | SKIPPED
     build:           PASS | FAIL | SKIPPED
     test:            PASS | FAIL | SKIPPED
     simplify:        PASS | FAIL
     review:          PASS | FAIL
     security-review: PASS | FAIL
     security-scan:   PASS | FAIL
   ```

4. Verify logs:

   ```bash
   ls .workflow/quality/$ARGUMENTS/final/attempt-<qualityAttempt>/gate-*.log 2>/dev/null | wc -l
   ```

   If fewer than 8, warn the user.

5. Shut down quality-final:

   ```
   SendMessage({ to: "quality-final", message: "shutdown" })
   ```

6. If `overall: PASS`, break out of the loop and proceed to Cleanup.

7. If `overall: FAIL`, ask the user via `AskUserQuestion`: "Final quality pass failed (attempt `<qualityAttempt>`). Retry, accept anyway, or stop?"
   - **Retry**: increment `qualityAttempt` and loop back to (1)
   - **Accept anyway**: break out of the loop, proceed to Cleanup
   - **Stop**: break out of the loop, proceed to Cleanup

### 7. Cleanup

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
  Work Complete (loop): $ARGUMENTS
══════════════════════════════════

Feature branch: feat/$ARGUMENTS

Specs processed this session:
  ✓ <spec 1>   (iter 1, committed)
  ✓ <spec 2>   (iter 2, committed)
  ⚠ <spec 3>   (skipped after 2 failed iterations)
  ✗ <spec 4>   (stopped — still incomplete)

Final quality pass: PASS | FAIL (accepted) | FAIL (stopped)
  Logs: .workflow/quality/$ARGUMENTS/final/

Per-spec evaluator logs:
  .workflow/quality/$ARGUMENTS/spec-*/iter-*/

Next steps:
  Review the feature branch and run /squash-pr $ARGUMENTS
══════════════════════════════════
```

---

## Error handling

- **Planner not responding**: Warn the user, offer to restart the planner (which wipes its running summary) or stop
- **Executor blocked**: User decides per spec — skip, retry, or stop
- **Evaluator unresolvable after 2 iterations**: User decides per spec — commit anyway, skip, or stop
- **Final quality pass unresolvable**: User decides — retry, accept anyway, or stop
- **Log files missing**: Warn but do not block; logs are advisory in this mode because the protocol messages are the source of truth

## Rules

- Do NOT read spec files — pass spec paths to agents, let them read
- Do NOT read source files — executor and evaluator own that
- Do NOT implement anything directly — delegate to the executor
- Do NOT run quality gates directly — delegate to the evaluator (per-spec) and quality (final pass)
- Do NOT commit directly — delegate to git-expert
- DO process specs strictly sequentially
- DO keep the planner alive across the whole task (shut down only after step 5)
- DO shut down executor, evaluator, and git-expert immediately after each one completes
- DO keep main agent context minimal — only PLAN, EXECUTION_COMPLETE, EVAL_REPORT, GIT_COMMIT_COMPLETE, and QUALITY_GATE_REPORT flow back
- DO pass plan blocks verbatim from planner → executor → evaluator so all three see the same plan
