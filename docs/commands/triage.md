# /triage

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/triage.md`  
**Also installed as:** `.claude/skills/triage/SKILL.md` (nested skill)  
**Requires:** gh CLI

Investigates a GitHub issue, explores the codebase to understand how to implement it, and posts a structured implementation plan as a comment on the issue.

## Usage

```
/triage <issue-number>           # Triage a single issue
/triage --milestone <number>     # Triage all open issues in a milestone
```

## What it does

1. Fetches the issue (or all milestone issues) via `gh issue view`
2. Explores the codebase — searches for relevant files, patterns, and existing implementations
3. Writes a structured triage comment covering:
   - **Summary** — what the issue is asking for
   - **Affected areas** — specific files and modules with brief explanation
   - **Implementation approach** — step-by-step plan with concrete references
   - **Considerations** — risks, open questions, edge cases
   - **Complexity** — Small / Medium / Large with justification
4. Posts the comment via `gh issue comment`

## Milestone mode

When triaging a milestone, issues are investigated in parallel using subagents (batched 3–5 at a time). Each issue gets its own triage comment. Issues with insufficient detail are skipped with a note in the summary.

## Notes

- The triage skill is also installed as a nested Claude Code skill at `.claude/skills/triage/`, making it available as a background skill in addition to a slash command
- Reference specific file paths and line numbers in triage comments — vague comments are not useful
- Reads `CLAUDE.md` and contributing guides to factor in project conventions
