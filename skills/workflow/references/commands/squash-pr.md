---
description: 'Squash all commits on a feature branch into one clean commit and open a PR'
---

# Squash & PR

Squash the feature branch down to a single clean commit and open a pull request. Works in two modes depending on how the branch was built:

- **Team mode** (`feat/$ARGUMENTS` with checkpoint commits per task) — squash all commits on the feature branch since it diverged from base

- **Subagent mode** (`feat/$ARGUMENTS-group-*` branches) — merge all group branches first, then squash

  **Input:** `$ARGUMENTS` — task list name (e.g. `issue-3`). Maps to `.workflow/tasks/$ARGUMENTS.md`. Required.

---

## Steps

### 1. Read the task list

Read `.workflow/tasks/$ARGUMENTS.md`. If it doesn't exist, tell the user and stop.

Extract:

- **Title** — the first line, matching `# Task Breakdown: <title>`. Strip the prefix to get the raw title.
- **Issue number** — parse from `$ARGUMENTS` using the pattern `issue-<N>` → `<N>`. If no match, proceed without an issue number.
- **Groups** — all `## Group N — <label>` entries with completion status.

### 2. Detect base branch

```bash
git branch -a
```

Determine whether the repo uses `main` or `master`. Store as `<base>`.

### 3. Detect mode and find the feature branch

**Check for team mode branch:**

```bash
git branch --list "feat/$ARGUMENTS"
```

**Check for subagent mode group branches:**

```bash
git branch --list "feat/$ARGUMENTS-group-*"
```

**Decision:**

- If `feat/$ARGUMENTS` exists → **team mode**

- If `feat/$ARGUMENTS-group-*` branches exist → **subagent mode**

- If neither exists → tell the user and stop. Suggest running `/work $ARGUMENTS --all` first.

  Warn about any groups with incomplete tasks (`- [ ]`). Ask the user if they want to continue anyway or stop.

### 4. Derive the target branch name

Convert the raw title to kebab-case:

- Lowercase everything

- Replace spaces and special characters with `-`

- Collapse multiple dashes

- Example: `Intent Screen Router & Path Management` → `feat/intent-screen-router-path-management`

  Store as `targetBranch`.

### 5. Detect git platform

```bash
git remote get-url origin
```

- Contains `github.com` → **GitHub** (use `gh` CLI)
- Contains `gitlab.com` or self-hosted GitLab → **GitLab** (use `glab` CLI)
- Contains `bitbucket.org` → **Bitbucket** (provide manual URL)

### 6. Build the source branch

**Team mode:**

The source branch is already `feat/$ARGUMENTS`. No merging needed — all checkpoint commits are already on it.

Confirm commits exist since base:

```bash
git log --oneline <base>..feat/$ARGUMENTS
```

If no commits, tell the user and stop.

**Subagent mode:**

Create a merge branch from base:

```bash
git checkout <base>
git checkout -b feat/$ARGUMENTS-merge
```

Merge all group branches in order:

```bash
git merge feat/$ARGUMENTS-group-<N> --no-ff --no-edit
```

If there are conflicts:

- Resolve by accepting incoming changes where unambiguous

- Document every conflict and resolution

- Stage and complete the merge:

  ```bash
  git add -A
  git commit --no-edit
  ```

  The merge branch is now the source for squashing. Store as `sourceBranch` = `feat/$ARGUMENTS-merge`.

  For team mode, `sourceBranch` = `feat/$ARGUMENTS`.

### 7. Create the target branch

Check if `targetBranch` already exists:

```bash
git branch --list "<targetBranch>"
```

If it exists, ask the user:

- `"Reset and rebuild"` — delete and recreate from `<base>`

- `"Stop"` — halt so the user can handle it manually

  Create from base:

```bash
git checkout <base>
git checkout -b <targetBranch>
git merge <sourceBranch> --ff-only 2>/dev/null || git merge <sourceBranch> --no-ff --no-edit
```

### 8. Squash to one commit

Find the merge base:

```bash
git merge-base <base> HEAD
```

Soft reset to it:

```bash
git reset --soft $(git merge-base <base> HEAD)
```

Generate the commit message:

```
feat(<scope>): <title lowercase, imperative> (#<issue>)

<PR body — see step 9>

Closes #<issue>
```

- `scope` — primary package or area affected, inferred from the task list (e.g. `session`, `auth`, `api`)

- Omit `(#<issue>)` and `Closes #<issue>` if no issue number

  Commit:

```bash
git commit -m "<message>"
```

Confirm:

```bash
git log --oneline <base>..HEAD
```

Should show exactly one commit.

### 9. Run the 8-gate quality pass

Before pushing, run the full 8-gate quality pass across the squashed commit to catch any regressions introduced during merge-conflict resolution (subagent mode) or to verify `/work` didn't skip remediation for a committed spec.

Initialize `qualityAttempt = 1`.

Loop:

1. Invoke a fresh quality subagent:

   ```
   Agent({
     subagent_type: "quality",
     model: "sonnet",
     description: "Squash-pr quality pass attempt <qualityAttempt>",
     prompt: `
       You are the quality agent running the pre-push full pass for squash-pr.
       Branch: <targetBranch>
       Task: $ARGUMENTS (squash-pr, attempt <qualityAttempt>)
       logDir: .workflow/quality/$ARGUMENTS/squash-pr/attempt-<qualityAttempt>/
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

2. Parse the `QUALITY_GATE_REPORT`.

3. Display:

   ```
   [squash-pr quality — attempt <qualityAttempt>]
     lint:            PASS | FAIL | SKIPPED
     typecheck:       PASS | FAIL | SKIPPED
     build:           PASS | FAIL | SKIPPED
     test:            PASS | FAIL | SKIPPED
     simplify:        PASS | FAIL
     review:          PASS | FAIL
     security-review: PASS | FAIL
     security-scan:   PASS | FAIL
   ```

4. If the quality agent auto-remediated anything, its fixes are on the squashed branch as one or more follow-up commits. Re-squash them into the single commit:

   ```bash
   git reset --soft $(git merge-base <base> HEAD)
   git commit -m "<previous squash commit message>"
   ```

   Skip this if the agent reported no remediation commits.

5. If `overall: PASS`, break out of the loop and continue to Step 10.

6. If `overall: FAIL`, ask the user via `AskUserQuestion`: "Squash-pr quality pass failed (attempt `<qualityAttempt>`). Findings: `<one-line summary>`. Retry, push anyway, or stop?"
   - **Retry**: increment `qualityAttempt` and loop back to (1)
   - **Push anyway**: record `qualityStatus = FAIL (accepted)` and break out of the loop
   - **Stop**: tell the user the squash commit is on `<targetBranch>` but nothing has been pushed. Exit the command.

Record the final `qualityStatus` (`PASS`, `FAIL (accepted)`) — it will be shown in the final summary (Step 14).

### 10. Build the PR body

```markdown
## Summary

<one paragraph describing what this PR does, derived from the task list title and group labels>

## Changes

### Group 1 — <label>

- ✅ Task title
- ✅ Task title

### Group 2 — <label>

- ✅ Task title
- ✅ Task title

...

## Test plan

<infer appropriate verification steps from task list content — build commands, key integration points, notable edge cases covered>

## Issue

Closes #<issue>
```

### 11. Push the branch

```bash
git push origin <targetBranch>
```

### 12. Open the PR

Check if a PR already exists for `targetBranch`:

- **GitHub:** `gh pr list --head <targetBranch>`

- **GitLab:** `glab mr list --source-branch <targetBranch>`

  If a PR already exists, print the existing PR URL and stop.

  If no PR exists, create one:

- **GitHub:**

  ```bash
  gh pr create \
    --title "feat(<scope>): <title> (#<issue>)" \
    --body "<PR body>" \
    --base <base>
  ```

- **GitLab:**

  ```bash
  glab mr create \
    --title "feat(<scope>): <title> (#<issue>)" \
    --description "<PR body>" \
    --target-branch <base>
  ```

- **Bitbucket:** Print the manual PR URL:

  ```
  https://bitbucket.org/<org>/<repo>/pull-requests/new?source=<targetBranch>
  ```

### 13. Cleanup (subagent mode only)

If subagent mode, remove the temporary merge branch:

```bash
git branch -d feat/$ARGUMENTS-merge
```

### 14. Summary

```
══════════════════════════════════
  Squash PR: $ARGUMENTS
══════════════════════════════════

  Mode:          team | subagent
  Task list:     .workflow/tasks/$ARGUMENTS.md
  Title:         <raw title>
  Source branch: <sourceBranch>
  Target branch: <targetBranch>
  Base branch:   <base>

  Commits squashed: <N>

  Quality pass:  PASS | FAIL (accepted)
    Logs: .workflow/quality/$ARGUMENTS/squash-pr/

  Groups included:
    Group 1 — <label>  (<N> tasks)
    Group 2 — <label>  (<N> tasks)
    ...

  Commit: feat(<scope>): <title> (#<issue>)

  PR: <url>

══════════════════════════════════
```
