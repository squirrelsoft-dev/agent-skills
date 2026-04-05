# /fix-issue

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/fix-issue.md`  
**Requires:** gh CLI

Implements a GitHub issue end-to-end: reads the issue, plans the implementation, writes the code, and opens a PR.

## Usage

```
/fix-issue <issue-number>
```

## What it does

1. Fetches the issue via `gh issue view`
2. Explores the codebase to understand the affected areas
3. Creates a branch named after the issue
4. Implements the fix or feature
5. Runs the quality gate
6. Creates a PR linked to the issue

## Notes

- For larger issues, consider using `/breakdown` + `/spec` + `/work` for more control over the implementation plan
