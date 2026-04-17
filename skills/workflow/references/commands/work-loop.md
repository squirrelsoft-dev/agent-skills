---
description: 'Implement a task list one spec at a time using a tight Planner → Executor → Evaluator loop, then run full quality gates once at the end'
---

# Work (Loop)

Implement a task list spec-by-spec using a **Planner → Executor → Evaluator** loop. For each spec the planner produces a plan, the executor implements it, and the evaluator runs mini-QA plus spec-compliance review. If the evaluator fails, the main agent asks the planner to replan (up to 2 iterations per spec) before escalating to the user. Once every spec is committed, a single full 8-gate quality pass runs at the end with auto-remediation. The main agent never reads spec files or source files — it only tracks state and orchestrates subagents via the `Agent` tool.

This mode is optimized for **spec-compliance correctness**, not raw speed. It catches cases where the implementation is "wrong per spec" (not just failing gates) that other `/work` modes silently commit.

**Input:** `$ARGUMENTS` — task list name, optionally followed by `--all` and/or `--mode <permission-mode>`

- `work <task-name>` — process every incomplete spec in the task list (this mode is sequential; `--all` is implied)
- `work <task-name> --all` — same as above, explicit
- `work <task-name> --mode auto` — spawn all subagents in `auto` permission mode
- `work <task-name> --mode bypassPermissions` — spawn all subagents in `bypassPermissions` mode (use with caution)
- Flags can be combined: `work <task-name> --all --mode auto`

---

## Orchestration model

This command uses **ephemeral subagents** via the `Agent` tool — not persistent team members. Each worker (planner, executor, evaluator, git-expert, quality) is invoked as a one-shot subagent per step; its response is returned synchronously as the Agent tool result. There is no `TeamCreate`, no team inbox, no `SendMessage` protocol, and no shutdown handshake.

Because subagents are stateless across invocations, the main agent carries a small **running planner summary** in its own context and passes it verbatim into every planner invocation. This replaces the persistent planner's internal memory from the team model.

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

1. **Create or switch to the feature branch**:

   ```bash
   git checkout -b feat/$ARGUMENTS 2>/dev/null || git checkout feat/$ARGUMENTS
   ```

2. **Initialize the running planner summary** — an empty markdown string the main agent will grow as specs complete:

   ```
   plannerSummary = ""
   ```

   After each PASS commit, append a bullet to `plannerSummary`:

   ```
   - <spec-title> (commit <sha>): <one-line what changed / key decision the next planner needs>
   ```

   Keep it compact (bullet points only, ≤ ~2k tokens). Drop details from completed specs once they are no longer relevant to future work.

3. Print the queue:

```
Work (loop): $ARGUMENTS
──────────────────────────
Feature branch: feat/$ARGUMENTS
Planner model: opus (fresh per invocation)

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

Invoke a fresh planner subagent via the `Agent` tool. Pass `plannerSummary` into the prompt so the planner has the same continuity it would have had as a persistent teammate. Pass `uiGlobs` so the planner can detect UI specs and include Playwright test instructions.

```
Agent({
  subagent_type: "planner",
  model: "opus",
  mode: "<permissionMode>",
  description: "Plan <spec-title> iter 1",
  prompt: `
    You are the planner for feat/$ARGUMENTS.
    Follow planner.md exactly.

    Running summary of completed specs on this task so far (for continuity):
    <plannerSummary, or "(none — this is the first spec)">

    uiGlobs: <uiGlobs or empty>

    Read the spec at: .workflow/specs/$ARGUMENTS/<kebab>.md
    Produce a PLAN block (iteration: 1). Return ONLY the PLAN...PLAN_END block as your final output — no prose around it.

    If the spec involves UI work and no Playwright skill is installed under .claude/skills/, return a PLAN_NEEDS_SKILL block instead (see planner.md).
  `
})
```

The subagent's final output is either a `PLAN` block or a `PLAN_NEEDS_SKILL` block.

**If the output is a `PLAN_NEEDS_SKILL` block:**

Ask the user via `AskUserQuestion`:

> "The planner needs a `<skill>` skill to plan this UI spec. Reason: `<reason>`. How to proceed?"
>
> Options:
> - **Install skill now** — run `/find-skills` in this session (or in a separate step) and ask it to install a Playwright skill. When the skill is in place, pick this option again to retry.
> - **Skip playwright for this spec** — planner will produce a PLAN without Playwright test instructions (the evaluator's E4 gate will SKIP if playwright isn't set up in the project either).
> - **Stop** — halt the workflow.

Handle the response:

- **Install skill now**: Re-invoke the planner from Step 4a (fresh subagent, same iteration). The planner will re-check for the skill and emit a `PLAN` block if it's now installed.
- **Skip playwright for this spec**: Re-invoke the planner from Step 4a with `skipPlaywright: true` appended to the prompt. The planner will produce a `PLAN` without Playwright instructions.
- **Stop**: Proceed to Cleanup.

**If the output is a `PLAN` block:** capture it verbatim — you will pass it to the executor and the evaluator.

---

**Step 4b — Execute plan**

Invoke a fresh executor subagent:

```
Agent({
  subagent_type: "executor",
  mode: "<permissionMode>",
  description: "Execute <spec-title> iter <N>",
  prompt: `
    You are the executor on branch feat/$ARGUMENTS.

    featureBranch: feat/$ARGUMENTS
    specPath: .workflow/specs/$ARGUMENTS/<kebab>.md

    plan: |
      <PASTE THE PLAN BLOCK FROM STEP 4a VERBATIM>

    Follow executor.md. Implement the plan, do NOT commit.
    Return ONLY the EXECUTION_COMPLETE...EXECUTION_COMPLETE_END block as your final output.
  `
})
```

Parse the returned `EXECUTION_COMPLETE` block.

If `status: blocked`:

- Ask the user via `AskUserQuestion`: "Executor blocked on `<spec-title>`: `<notes>`. Skip spec, retry, or stop?"
- Handle response:
  - **Skip**: `git checkout -- .` to discard uncommitted changes, continue to next spec
  - **Retry**: loop back to Step 4b with a fresh executor invocation (still iteration 1)
  - **Stop**: proceed to Cleanup

---

**Step 4c — Evaluate**

Invoke a fresh evaluator subagent:

```
Agent({
  subagent_type: "evaluator",
  mode: "<permissionMode>",
  description: "Evaluate <spec-title> iter <N>",
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

    Follow evaluator.md. Do NOT modify source code.
    Return ONLY the EVAL_REPORT...EVAL_REPORT_END block as your final output.
  `
})
```

Parse the returned `EVAL_REPORT` block.

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

---

**Step 4d — Decide**

**If `overall: PASS`:**

Proceed to Step 4e (commit).

**If `overall: FAIL` and iteration < 2:**

Invoke the planner again (fresh subagent) with a `REPLAN` prompt:

```
Agent({
  subagent_type: "planner",
  model: "opus",
  mode: "<permissionMode>",
  description: "Replan <spec-title> iter 2",
  prompt: `
    You are the planner for feat/$ARGUMENTS.
    Follow planner.md exactly — REPLAN protocol.

    Running summary of completed specs so far:
    <plannerSummary, or "(none)">

    uiGlobs: <uiGlobs or empty>

    Previous PLAN for this spec:
    <PASTE THE PLAN BLOCK FROM ITERATION 1 VERBATIM>

    Evaluator findings from the executor's iteration-1 attempt (still on disk):
    <PASTE THE findings BLOCK FROM THE EVAL_REPORT VERBATIM>

    Spec path: .workflow/specs/$ARGUMENTS/<kebab>.md

    Inspect the current state of changed files (the executor's prior attempt is on disk — the replan edits in place, not from scratch). Produce a new PLAN block (iteration: 2) that explicitly addresses every finding. Return ONLY the PLAN...PLAN_END block.

    If this is a UI spec and no Playwright skill is installed under .claude/skills/, return a PLAN_NEEDS_SKILL block instead (see planner.md). Handle it the same way as iteration 1.
  `
})
```

Capture the new `PLAN` and loop back to Step 4b with iteration = 2. (Do NOT discard the executor's previous changes — the replan edits them in place.)

If the replan returns `PLAN_NEEDS_SKILL`, handle it exactly as in Step 4a (install / skip playwright / stop).

**If `overall: FAIL` and iteration == 2:**

Ask the user via `AskUserQuestion`: "Spec `<title>` failed evaluation twice. Findings: `<one-line summary>`. Commit anyway, skip spec, or stop?"

- **Commit anyway**: proceed to Step 4e
- **Skip spec**: `git checkout -- .` to discard uncommitted changes, continue to next spec (do NOT mark the task complete in the task file)
- **Stop**: proceed to Cleanup

---

**Step 4e — Commit checkpoint**

Invoke a fresh git-expert subagent for this commit only:

```
Agent({
  subagent_type: "git-expert",
  mode: "<permissionMode>",
  description: "Commit <spec-title>",
  prompt: `
    You are the git-expert for feat/$ARGUMENTS.
    Execute this single COMMIT operation. Do NOT push. Do NOT modify history.

    Operation: COMMIT
    branch: feat/$ARGUMENTS
    message: feat: <spec title>
    taskListFile: .workflow/tasks/$ARGUMENTS.md
    taskTitle: <spec title>

    Stage only the files changed for this spec (those listed in the executor's EXECUTION_COMPLETE.filesChanged) plus the task list. Do NOT stage unrelated working-tree files.

    Return ONLY the GIT_COMMIT_COMPLETE...GIT_COMMIT_COMPLETE_END block as your final output.
  `
})
```

Parse the returned `GIT_COMMIT_COMPLETE` and capture the commit SHA.

Append a one-line entry to `plannerSummary`:

```
- <spec-title> (<sha>): <one-line what changed / key decision>
```

Print:

```
  ✓ <spec title>  (iter <N>, checkpoint <sha>)
```

Continue to the next spec in the queue.

---

### 5. Final full quality pass

If the user chose **Stop** earlier, skip this step and proceed to Cleanup.

Otherwise, run the full 8-gate quality pass once across the entire feature branch, with iterative retries until it passes or the user stops.

Initialize `qualityAttempt = 1`.

Loop:

1. Invoke a fresh quality subagent:

   ```
   Agent({
     subagent_type: "quality",
     model: "sonnet",
     mode: "<permissionMode>",
     description: "Final quality pass attempt <qualityAttempt>",
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
       Return ONLY the QUALITY_GATE_REPORT...QUALITY_GATE_REPORT_END block as your final output.
     `
   })
   ```

2. Parse the `QUALITY_GATE_REPORT` from the subagent's output.

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

5. If `overall: PASS`, break out of the loop and proceed to Cleanup.

6. If `overall: FAIL`, ask the user via `AskUserQuestion`: "Final quality pass failed (attempt `<qualityAttempt>`). Retry, accept anyway, or stop?"
   - **Retry**: increment `qualityAttempt` and loop back to (1)
   - **Accept anyway**: break out of the loop, proceed to Cleanup
   - **Stop**: break out of the loop, proceed to Cleanup

### 6. Cleanup

Print final summary:

```
══════════════════════════════════
  Work Complete (loop): $ARGUMENTS
══════════════════════════════════

Feature branch: feat/$ARGUMENTS

Specs processed this session:
  ✓ <spec 1>   (iter 1, committed <sha>)
  ✓ <spec 2>   (iter 2, committed <sha>)
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

No team to tear down — all subagents were one-shot invocations and have already returned.

---

## Error handling

- **Planner returns no PLAN block**: Re-invoke the planner once with an explicit reminder to return only the PLAN…PLAN_END block. If it still fails, warn the user and offer to stop.
- **Planner returns PLAN_NEEDS_SKILL**: Ask the user (install skill / skip playwright / stop) as described in Step 4a. Do NOT treat this as an error — it is a normal protocol path for UI specs when a Playwright skill is missing.
- **Executor blocked**: User decides per spec — skip, retry, or stop
- **Evaluator unresolvable after 2 iterations**: User decides per spec — commit anyway, skip, or stop
- **Final quality pass unresolvable**: User decides — retry, accept anyway, or stop
- **Log files missing**: Warn but do not block; logs are advisory in this mode because the structured blocks returned by subagents are the source of truth
- **Malformed protocol block**: If a subagent returns prose instead of the expected structured block, quote the raw output to the user and ask whether to retry the same step or stop

## Rules

- Do NOT read spec files — pass spec paths to subagents, let them read
- Do NOT read source files — executor and evaluator own that
- Do NOT implement anything directly — delegate to the executor subagent
- Do NOT run quality gates directly — delegate to the evaluator (per-spec) and quality (final pass) subagents
- Do NOT commit directly — delegate to the git-expert subagent
- Do NOT use `TeamCreate`, `TeamDelete`, or `SendMessage` — every worker is a one-shot `Agent` invocation
- DO process specs strictly sequentially
- DO maintain `plannerSummary` in the main agent's context across specs and pass it into every planner invocation (replaces the team model's persistent planner memory)
- DO keep main agent context minimal — only PLAN, PLAN_NEEDS_SKILL, EXECUTION_COMPLETE, EVAL_REPORT, GIT_COMMIT_COMPLETE, and QUALITY_GATE_REPORT flow back
- DO pass plan blocks verbatim from planner → executor → evaluator so all three see the same plan
