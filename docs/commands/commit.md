# /commit

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/commit.md`

Generates a conventional commit message for staged changes and commits them.

## Usage

```
/commit
```

## What it does

Reads `git diff --staged` and the recent commit history to understand the change, then writes a commit message following the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]
```

Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`.

## Notes

- Only commits staged changes — run `git add` first
- If nothing is staged, reports that and stops
