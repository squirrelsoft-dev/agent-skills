# /review

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/review.md`

Reviews the current set of changes against the branch's base.

## Usage

```
/review
```

## What it does

Runs a code review over `git diff` between the current branch and its base. Checks for:
- Logic errors and edge cases
- Security issues
- Code style inconsistencies with `.claude/rules/`
- Missing tests
- Unintended scope changes

Outputs a structured review report with specific file and line references.
