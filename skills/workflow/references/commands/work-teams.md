---
description: 'Implement a group-based task breakdown using a coordinated agent team'
---

# Work (Team)

Orchestrate implementation of a group-based task breakdown by spawning a Manager agent that coordinates domain-implementer teammates and a Quality Gate agent. The Manager absorbs all verbose output — the main agent only sees compact status reports and user decision prompts.

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

2. **Create tasks** — For each incomplete group, call `TaskCreate` with:
   - `subject`: `$ARGUMENTS — Group <N>: <label>`
   - `description`: Comma-separated list of incomplete task titles in the group

3. **Set up dependencies** via `TaskUpdate`:
   - If a group has `_Depends on: Group N_`, add `addBlockedBy` on the depended group's task

4. **Identify unique domains** — Collect all unique domain labels across all groups, along with their `Files owned:` declarations.

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

### 4. Spawn the Manager

Create a team and spawn the Manager as a named teammate:

```
TeamCreate({ team_name: "work-$ARGUMENTS" })

Agent({
  team_name: "work-$ARGUMENTS",
  name: "manager",
  agent: "manager",
  prompt: `
    mode: teams
    taskListName: $ARGUMENTS
    taskListFile: .claude/tasks/$ARGUMENTS.md
    featureBranch: feat/$ARGUMENTS
    specDir: .claude/specs/$ARGUMENTS/
    domains:
      - label: <domain-label>
        filesOwned: <files owned>
      - label: <domain-label>
        filesOwned: <files owned>
    sharedFiles:
      <full Shared Files table>
    lintCmd: <project lint command or empty>
    typecheckCmd: <project typecheck command or empty>
    buildCmd: <project build command or empty>
    testCmd: <project test command or empty>

    Wait for START_GROUP messages. For each group, spawn
    domain-implementer teammates, coordinate work, run Quality
    agent. Send ASK_USER for decisions. Send MANAGER_REPORT
    when the group is complete.
  `
})
```

### 5. Process groups

For each group in dependency order, send a `START_GROUP` message to the Manager:

```
SendMessage({
  to: "manager",
  message: `
    START_GROUP
    groupNumber: <N>
    groupLabel: <label>
    tasks:
      - domain: <domain-label>
        title: <task title>
        spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
      - domain: <domain-label>
        title: <task title>
        spec: .claude/specs/$ARGUMENTS/<task-title-kebab>.md
    logDir: .claude/quality/$ARGUMENTS/group-<N>/
    START_GROUP_END
  `
})
```

Then enter a **message loop** — wait for messages from the Manager and handle them:

- **`ASK_USER` message**: Parse the question and options. Call `AskUserQuestion` with them. Send the user's choice back:
  ```
  SendMessage({
    to: "manager",
    message: `
      USER_ANSWER
      answer: <user's choice>
      USER_ANSWER_END
    `
  })
  ```
  If the user chose `stop`, also stop the main loop after the Manager sends its MANAGER_REPORT.

- **`MANAGER_REPORT` message**: Parse the report. Exit the message loop for this group.

### 6. Verify QA logs

After each MANAGER_REPORT, verify the Quality agent actually ran all gates:

```bash
ls .claude/quality/$ARGUMENTS/group-<N>/gate-*.log 2>/dev/null | wc -l
```

Expected: 8 log files. If fewer exist, warn the user:
```
Warning: Only <N>/8 quality gate logs found at .claude/quality/$ARGUMENTS/group-<N>/
Some gates may not have run. Review the logs before proceeding.
```

Also check `report.md` exists in the same directory.

### 7. Handle results

Parse the MANAGER_REPORT:

If `status: PASS`:
1. Call `TaskUpdate(status: completed)` for the group's task entry. The `TaskCompleted` hook fires.
2. Read `.claude/tasks/$ARGUMENTS.md` and flip `- [ ]` to `- [x]` for every task in this group.

If `status: FAIL`:
- The user already made their decision during ASK_USER (continue/stop)
- If they chose `stop`, halt the loop

Print group progress:
```
──────────────────────────
✓ Group <N> — <label> complete
  QA logs: .claude/quality/$ARGUMENTS/group-<N>/
  Next: Group <M> — <label>   (or "All groups complete")
──────────────────────────
```

If `--all` flag is set and more groups remain, loop back to step 5 for the next group.

### 8. Commit and cleanup

After all groups are processed:

1. **Stage all changes**:
   ```bash
   git add -A
   ```

2. **Create a single commit** on the feature branch:
   ```bash
   git commit -m "feat: <task list title from the # heading>"
   ```

3. **Send shutdown to the Manager**:
   ```
   SendMessage({ to: "manager", message: "shutdown" })
   ```

4. **Delete the team**:
   ```
   TeamDelete({ team_name: "work-$ARGUMENTS" })
   ```

5. **Print final summary**:

```
══════════════════════════════════
  Team Work Complete: $ARGUMENTS
══════════════════════════════════

Feature branch: feat/$ARGUMENTS

Groups completed this session:
  ✓ Group 1 — <label>  (QA: PASS, logs: .claude/quality/$ARGUMENTS/group-1/)
  ✓ Group 2 — <label>  (QA: PASS, logs: .claude/quality/$ARGUMENTS/group-2/)

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

- **Manager not responding**: If no message is received within a reasonable time, warn the user and suggest restarting
- **Malformed MANAGER_REPORT**: Treat as FAIL, show raw output to user
- **Missing QA logs**: Warn user even if MANAGER_REPORT says PASS — log files are the source of truth for gate execution
- **Blocked groups** (in `--all` mode): if a group's dependencies are unmet after prior groups complete, report blockage and stop

## Rules

- Do NOT implement anything directly — the Manager delegates to domain-implementer teammates
- Do NOT run quality gates directly — the Manager delegates to the Quality agent
- Do NOT skip QA log verification — always check that 8 gate log files exist after each group
- Do NOT process groups in parallel — dependency order must be respected
- Do NOT commit until all quality gates pass for completed groups
- DO keep main agent context minimal — only ASK_USER messages and MANAGER_REPORT flow back
- DO verify QA logs independently after each MANAGER_REPORT
- DO send group assignments only via the Manager — never directly to domain agents
