# /address-pr-comments

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/address-pr-comments.md`  
**Requires:** gh CLI

Fetches all open review comments on the current PR and addresses them.

## Usage

```
/address-pr-comments
```

## What it does

1. Fetches open review comments from the current branch's PR via `gh pr view`
2. Groups comments by file
3. Addresses each comment, making the requested changes or explaining why a change isn't being made
4. Runs the quality gate before finishing
5. Commits the changes with a message referencing the review
