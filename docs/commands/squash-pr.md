# /squash-pr

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/squash-pr.md`  
**Requires:** gh CLI

Squashes all commits on the current branch into a single clean commit, then creates a GitHub pull request.

## Usage

```
/squash-pr <feature-name>
```

## What it does

1. Identifies all commits since the branch diverged from main
2. Squashes them into a single conventional commit with a well-formed message summarising all changes
3. Creates a PR via `gh pr create` with a full description

## When to use

After using `/work` with the subagents mode — multiple worktree merges produce many commits. `/squash-pr` cleans the history before opening the PR.
