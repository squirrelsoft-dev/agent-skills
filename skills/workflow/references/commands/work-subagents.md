---
description: 'Implement the next task group (or all groups) from a task breakdown using focused agents'
---

# Work

Orchestrate implementation of a task breakdown by spawning a team of agents and letting the Manager coordinate them. The main agent spawns all teammates, sends group assignments, handles user decisions, and verifies QA logs. The Manager coordinates Git Expert, Implementers, and Quality via messages — it never spawns agents.

**Input:** `$ARGUMENTS` — task list name, optionally followed by `--all` and/or `--mode <permission-mode>`

- `work <task-name>` — implement the next available group only
- `work <task-name> --all` — enqueue and implement every incomplete group in dependency order
- `work <task-name> --mode auto` — spawn all teammates in `auto` permission mode (no permission prompts during agent execution)
- `work <task-name> --mode bypassPermissions` — spawn all teammates in `bypassPermissions` mode (use with caution)
- Flags can be combined: `work <task-name> --all --mode auto`

---

## Steps

### 1. Parse arguments

Split `$ARGUMENTS` on whitespace. Extract:
- `taskListName` — first non-flag token (e.g. `issue-3`)
- `allFlag` — true if `--all` is present
- `permissionMode` — value following `--mode` if present. Allowed values: `default`, `acceptEdits`, `auto`, `bypassPermissions`. If `--mode` is not provided, default to `acceptEdits`. If an invalid value is supplied, tell the user and stop.

Read `.workflow/tasks/<taskListName>.md`. If it doesn't exist, tell the user and stop.

### 2. Check file format

If the file contains `## Domain:` headers instead of `## Group N —` headers, tell the user: "This task file uses domain format. Use `/work $ARGUMENTS` instead." and stop.

### 3. Parse the task list

Parse the file structure:

- Groups are headed by `## Group N — <label>` lines
- Tasks match `- [ ] **Task title**` (incomplete) or `- [x] **Task title**` (complete)
- A group is **complete** if all its tasks are `- [x]`
- A group is **available** if not complete AND all groups in its `_Depends on: ..._` line are complete
- A group is **blocked** if any dependency group has incomplete tasks

If all groups are already complete, tell the user and stop.

### 4. Verify specs exist

Before doing anything, check that `.workflow/specs/<taskListName>/` contains a spec file for every incomplete task across all groups you intend to process. For each incomplete task, look for `.workflow/specs/<taskListName>/<task-title-kebab>.md`.

If any specs are missing, list them and suggest running `/spec <taskListName>` first. Stop.

### 5. Disable stop hooks

Create a flag file so the stop-quality-gate hook skips during the workflow run (teams manage their own QA):
```bash
touch .claude/.workflow-running
```

### 6. Enqueue groups via TaskCreate

**If `--all` flag:**
For each incomplete group in dependency order, call `TaskCreate` with:
- `title`: `<taskListName> — Group <N>: <label>`
- `description`: comma-separated list of incomplete task titles in the group

Print the queue:
```
Work All: <taskListName>
──────────────────────────
[queued] Group 1 — <label>  (<N> tasks)
[queued] Group 2 — <label>  (<N> tasks)
...
[complete] Group N — <label>  (skipped)
──────────────────────────
```

**If single group:**
Find the next available group. If multiple are available, use `AskUserQuestion` to let the user pick. Auto-select if only one is available. Call `TaskCreate` for that group only.

### 7. Create team

```
TeamCreate({ team_name: "work-<taskListName>" })
```

### 8. Process groups

For each group in dependency order:

#### 8a. Spawn all agents for this group

All agents are **ephemeral per group** — spawned fresh with clean context at the start of each group and shut down at the end. This prevents context bloat across groups.

**Spawn the Manager:**
```
Agent({
  team_name: "work-<taskListName>",
  name: "manager",
  agent: "manager",
  mode: "<permissionMode>",
  prompt: `
    mode: subagents
    taskListName: <taskListName>
    taskListFile: .workflow/tasks/<taskListName>.md
    specDir: .workflow/specs/<taskListName>/
    lintCmd: <project lint command or empty>
    typecheckCmd: <project typecheck command or empty>
    buildCmd: <project build command or empty>
    testCmd: <project test command or empty>

    You coordinate via SendMessage only. Wait for a START_GROUP message.
  `
})
```

**Spawn the Git Expert:**
```
Agent({
  team_name: "work-<taskListName>",
  name: "git-expert",
  agent: "git-expert",
  mode: "<permissionMode>",
  prompt: `
    You are the Git Expert. Wait for operation messages (SETUP, MERGE, VERIFY)
    from the manager. Execute each operation and send the structured response
    back to the manager.
  `
})
```

**Spawn the Quality agent:**
```
Agent({
  team_name: "work-<taskListName>",
  name: "quality",
  agent: "quality",
  mode: "<permissionMode>",
  prompt: `
    You are the Quality agent. Wait for RUN_GATES messages from the manager.
    For each request, run all 8 quality gates. Send QA_PROGRESS notifications
    to the manager when gates fail or remediation occurs. Send the final
    QUALITY_GATE_REPORT back to the manager when complete.
  `
})
```

**Spawn implementer teammates for this group** — one per incomplete task:
```
Agent({
  team_name: "work-<taskListName>",
  name: "impl-<agentNumber>",
  agent: "implementer",
  mode: "<permissionMode>",
  prompt: `
    You are an implementer agent. Wait for a TASK_ASSIGNMENT message
    from the manager. Implement the spec, commit your changes, and
    send IMPLEMENTATION_COMPLETE back to the manager.
  `
})
```

Spawn all agents in parallel.

#### 8b. Send START_GROUP to the Manager

```
SendMessage({
  to: "manager",
  message: `
    START_GROUP
    groupNumber: <N>
    groupLabel: <label>
    tasks:
      - agentNumber: 1
        title: <task title>
        spec: .workflow/specs/<taskListName>/<task-title-kebab>.md
      - agentNumber: 2
        title: <task title>
        spec: .workflow/specs/<taskListName>/<task-title-kebab>.md
    logDir: .workflow/quality/<taskListName>/group-<N>/
    teammates: [git-expert, quality, impl-1, impl-2, ...]
    START_GROUP_END
  `
})
```

#### 8c. Message loop

Wait for messages from the Manager and handle them:

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

- **`QA_STATUS` message**: Display as a progress line to the user:
  ```
  [QA] Gate <gate>: <status> — <detail>
  ```

- **`MANAGER_REPORT` message**: Parse the report. Exit the message loop for this group.

#### 8d. Shut down all group agents

After the MANAGER_REPORT is received, shut down all agents spawned for this group so their context is released:
```
SendMessage({ to: "manager", message: "shutdown" })
SendMessage({ to: "git-expert", message: "shutdown" })
SendMessage({ to: "quality", message: "shutdown" })
SendMessage({ to: "impl-1", message: "shutdown" })
SendMessage({ to: "impl-2", message: "shutdown" })
...
```

### 9. Verify QA logs

After each MANAGER_REPORT, verify the Quality agent actually ran all gates:

```bash
ls .workflow/quality/<taskListName>/group-<N>/gate-*.log 2>/dev/null | wc -l
```

Expected: 8 log files. If fewer exist, warn the user:
```
Warning: Only <N>/8 quality gate logs found at .workflow/quality/<taskListName>/group-<N>/
Some gates may not have run. Review the logs before proceeding.
```

Also check `report.md` exists in the same directory.

### 10. Handle results

Parse the MANAGER_REPORT:

If `status: PASS`:
1. Call `TaskUpdate` to mark the group's task entry as complete
2. Read `.workflow/tasks/<taskListName>.md` and flip `- [ ]` to `- [x]` for every task in this group

If `status: FAIL`:
- The user already made their decision during ASK_USER (continue/stop/merge-anyway)
- If they chose `stop`, halt the loop

### 11. Print group progress

```
──────────────────────────
✓ Group <N> — <label> complete. Feature branch: feat/<taskGroupName>
  Tasks completed: <N>  |  Failed: <N>
  QA logs: .workflow/quality/<taskListName>/group-<N>/
  Next: Group <M> — <label>   (or "All groups complete")
──────────────────────────
```

If `--all` flag is set and more groups remain, loop back to step 8 for the next group.

### 12. Cleanup

After all groups are processed (or the user stops):

1. **Re-enable stop hooks** — remove the workflow flag file:
   ```bash
   rm -f .claude/.workflow-running
   ```

2. **Delete the team** (agents were already shut down per-group in step 8d):
   ```
   TeamDelete({ team_name: "work-<taskListName>" })
   ```

### 13. Final summary

```
══════════════════════════════════
  Work Complete: <taskListName>
══════════════════════════════════

Groups completed this session:
  ✓ Group 1 — <label>  →  feat/<taskGroupName>  (QA: PASS, logs: .workflow/quality/...)
  ✓ Group 2 — <label>  →  feat/<taskGroupName>  (QA: PASS, logs: .workflow/quality/...)

Previously complete (skipped):
  ✓ Group N — <label>

Still incomplete (if any):
  ✗ Group M — <label>  (<reason>)

Next steps:
  Review feature branches and run /squash-pr when ready.
══════════════════════════════════
```

---

## Error handling

- **Manager not responding**: If no message is received within a reasonable time, warn the user and suggest restarting
- **Malformed MANAGER_REPORT**: Treat as FAIL, show raw output to user
- **Missing QA logs**: Warn user even if MANAGER_REPORT says PASS — log files are the source of truth for gate execution
- **Blocked groups** (in `--all` mode): if a group's dependencies are unmet after prior groups complete, report blockage and stop

## Rules

- Do NOT implement anything directly — delegate via the Manager to Implementer teammates
- Do NOT merge anything directly — delegate via the Manager to the Git Expert teammate
- Do NOT run quality gates directly — delegate via the Manager to the Quality teammate
- Do NOT skip QA log verification — always check that 8 gate log files exist after each group
- Do NOT process groups in parallel — dependency order must be respected
- DO spawn all agents fresh per group and shut them down after — every agent is ephemeral to prevent context bloat
- DO spawn all agents as teammates — the Manager never spawns agents
- DO keep main agent context minimal — only QA_STATUS, ASK_USER, and MANAGER_REPORT flow back
- DO verify QA logs independently after each MANAGER_REPORT
