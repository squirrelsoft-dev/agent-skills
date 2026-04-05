# testing.md

**Rule file:** `.claude/rules/testing.md`  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)  
**Applies to:** `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`, `tests/**`, `test/**`

Testing standards for all test files. The path scope means these rules are only injected into Claude's context when working in test files, keeping the main context uncluttered.

## Rules

- **Test behaviour, not implementation** — assert on outcomes, not internal method calls
- **Cover edge cases** — empty inputs, null values, boundary conditions
- **Descriptive names** — test names should read as sentences explaining what is verified
- **Mock external services** — never hit real APIs, databases, or filesystems in unit tests
- **Tests before done** — run tests before marking any task complete
