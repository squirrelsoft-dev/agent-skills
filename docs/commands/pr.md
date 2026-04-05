# /pr

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/pr.md`  
**Requires:** gh CLI

Creates a GitHub pull request for the current branch.

## Usage

```
/pr
```

## What it does

Generates a PR title and description from the branch's commits and changed files, then creates the PR via `gh pr create`. The description includes a summary of changes, motivation, and a testing checklist.
