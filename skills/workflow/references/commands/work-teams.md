---
description: 'Implement a domain-based task breakdown using a coordinated agent team'
---

# Work (Team)

Orchestrate implementation of a domain-based task breakdown by spawning a team of domain-implementer agents. Each agent owns a non-overlapping slice of the codebase and works through its tasks sequentially. All agents run in parallel on a single feature branch. After all agents finish: verification → quality gates → build/test → single commit.

**Input:** `$ARGUMENTS` — task list name (e.g., `work my-feature`)

---

## Steps

### 1. Parse and validate

Read `.claude/tasks/$ARGUMENTS.md`. If it doesn't exist, tell the user and stop.

Verify the file uses **domain format** — it should contain `## Domain:` headers. If it contains `## Group N —` headers instead, tell the user: "This task file uses group format. Use `/work` instead." and stop.

Parse the file to extract:
- Each domain's label, agent name, owned files, and prerequisite status
- All tasks within each domain with their order, descriptions, and coordination points
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

3. **Create tasks** — For each incomplete task across all domains, call `TaskCreate` with:
   - `subject`: `[<domain-label>] <task title>`
   - `description`: Path to spec file and any dependency info

4. **Set up dependencies** via `TaskUpdate`:
   - Within-domain `Depends on:` → `addBlockedBy` on the depended task
   - If any domain is marked `[prerequisite]`, all tasks in non-prerequisite domains are blocked by ALL tasks in the prerequisite domain

Print the queue:
```
Work Team: $ARGUMENTS
──────────────────────────
Feature branch: feat/$ARGUMENTS

Domains:
  <domain-label>  (<N> tasks)  <files owned>
  <domain-label>  (<N> tasks)  <files owned>
  ...
──────────────────────────
```

### 4. Spawn teammates

Spawn one teammate per domain. All teammates work directly on the feature branch — no worktrees, no per-domain branches.

For each domain:

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

    ## Your Tasks (in execution order)

    <for each task in this domain, ordered by [order: N]:>
    ### Task: <task title> [order: <N>]
    Spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
    Coordinates with: <cross-domain refs>
    <Depends on: <within-domain deps> if any>

    ## Shared Files

    <full Shared Files table>

    ## Instructions

    Work through your tasks in order:

    1. Call TaskList to find the next unblocked, unowned task matching your domain [<domain-label>]
    2. Claim it via TaskUpdate(owner: "impl-<domain-label>", status: in_progress)
    3. Read the spec file for this task
    4. Read existing code in the listed files
    5. If the task involves an unfamiliar library or pattern:
       npx skills find <topic>
       npx skills add <owner/repo@skill>
    6. Implement the changes described in the spec
    7. Mark task completed via TaskUpdate(status: completed)
    8. Send progress message to orchestrator via SendMessage:
       Domain: <domain-label>
       Completed: <task title>
       Remaining: <count>
       Issues: <any problems, or "none">
    9. Loop back to step 1

    When no more tasks remain, send:
       DOMAIN_COMPLETE
       domain: <domain-label>
       tasksCompleted: <count>
       issues: <summary or "none">
       DOMAIN_COMPLETE_END

    ## Critical Rules

    - NEVER modify files outside your owned paths
    - Do NOT commit — leave changes uncommitted
    - Do NOT push or run destructive git commands
    - For shared files, follow the Strategy column in the Shared Files table
    - Follow specs exactly; if ambiguous, make the conservative choice and note it
    - Read existing code before writing new code; match surrounding style
  `
})
```

If a prerequisite domain exists, spawn its teammate first and wait for it to complete before spawning the remaining teammates.

### 5. Monitor progress

As teammates work:
- Receive progress messages automatically
- Print updates to the user as each task completes:
  ```
  [impl-<domain>] ✓ <task title>  (<N> remaining)
  ```
- If a teammate reports failure, ask the user via `AskUserQuestion`:
  - `"Continue with other domains"` — let remaining teammates finish
  - `"Stop"` — shut down all teammates and stop

Wait for all teammates to send `DOMAIN_COMPLETE`.

Print domain summary:
```
──────────────────────────
All domains complete.
  impl-ui:     5/5 tasks
  impl-api:    3/3 tasks
  impl-data:   2/2 tasks
──────────────────────────
```

### 6. Verification

Spawn a **verification agent** (general-purpose, NOT a teammate) to confirm all planned changes were implemented:

```
Agent({
  subagent_type: "general-purpose",
  prompt: `
    You are a verification agent. Your job is to confirm that all planned changes
    from a task breakdown were actually implemented.

    Task list: .claude/tasks/$ARGUMENTS.md
    Specs directory: .claude/specs/$ARGUMENTS/

    For each task in the task list:
    1. Read the spec file
    2. Check that every change described in the spec's Implementation Details
       section is present in the actual codebase
    3. Check that verification steps listed in the spec pass

    Do NOT fix anything. Only report.

    Output format:

    VERIFICATION_REPORT_START
    <for each task:>
    - <task title>: PASS | GAPS
      <if GAPS: list what is missing or deviates from spec>
    overall: PASS | GAPS
    VERIFICATION_REPORT_END
  `
})
```

If gaps are found, ask the user via `AskUserQuestion`:
- `"Send teammates back to fix gaps"` — wake affected domain teammates via `SendMessage` with the specific gaps to address, wait for them to finish
- `"Continue anyway"` — proceed to quality gates
- `"Stop"` — shut down and stop

### 7. Quality gates

Run the full 4-gate QA on all uncommitted changes on the feature branch. Spawn a **Quality** agent:

```
Agent({
  agent: "quality",
  run_in_background: false,
  prompt: `
    branch: feat/$ARGUMENTS
    taskTitle: $ARGUMENTS (full feature)
    specFile: .claude/tasks/$ARGUMENTS.md

    Run all four quality gates on the uncommitted changes on this branch.
    This covers all domains' combined work.
  `
})
```

Parse the `QA_REPORT_START ... QA_REPORT_END` block. Show results:

```
QA Results — feat/$ARGUMENTS
  Simplify        [PASS|FAIL]
  Review          [PASS|FAIL]
  Security Review [PASS|FAIL]
  Security Scan   [PASS|FAIL]
  Overall: [PASS|FAIL]
```

If overall **FAIL**, ask via `AskUserQuestion`:
- `"Accept and continue"` ⚠️
- `"Stop"` 🛑

### 8. Build / Lint / Test

Run verification commands on the feature branch:

```bash
npm run build
npm run lint
npm run typecheck
npm test
```

Report pass/fail for each. If any fail, ask the user via `AskUserQuestion`:
- `"Fix and re-run"` — spawn a remediation agent to fix, then re-run failed commands
- `"Accept anyway"` ⚠️
- `"Stop"` 🛑

### 9. Commit and cleanup

1. **Stage all changes**:
   ```bash
   git add -A
   ```

2. **Create a single commit** on the feature branch:
   ```bash
   git commit -m "feat: <task list title from the # heading>"
   ```

3. **Mark tasks complete** — Read `.claude/tasks/$ARGUMENTS.md` and flip all `- [ ]` to `- [x]` for tasks that were completed.

4. **Shutdown teammates**:
   ```
   SendMessage({ to: "*", message: { type: "shutdown_request" } })
   ```

5. **Delete the team**:
   ```
   TeamDelete()
   ```

6. **Print final summary**:

```
══════════════════════════════════
  Team Work Complete: $ARGUMENTS
══════════════════════════════════

Feature branch: feat/$ARGUMENTS

Domain results:
  ✓ impl-ui:     5/5 tasks completed
  ✓ impl-api:    3/3 tasks completed
  ✓ impl-data:   2/2 tasks completed

Verification: PASS
Quality gate: PASS
Build/Lint/Test: PASS

Commit: <short sha> feat: <title>

Next steps:
  Review the feature branch and open a PR.
══════════════════════════════════
```

---

## Error handling

- **Teammate failure**: warn user, offer continue-with-other-domains or stop
- **Verification gaps**: offer send-back, continue-anyway, or stop
- **QA failure**: offer accept or stop
- **Build/test failure**: offer fix, accept, or stop
- **Prerequisite domain failure**: stop all — other domains cannot proceed without prerequisite

## Rules

- Do NOT implement anything directly — always delegate to domain-implementer teammates
- Do NOT commit until all verification and quality gates pass
- Do NOT skip the verification phase — every planned change must be confirmed
- Do NOT skip the quality gate phase
- DO spawn all non-prerequisite domain teammates in parallel
- DO process prerequisite domains first, before spawning other teammates
