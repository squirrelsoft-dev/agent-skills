# general.md

**Rule file:** `.claude/rules/general.md`  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)  
**Applies to:** All files (no path scope)

Core code quality rules that apply across the entire codebase regardless of file type or stack.

## Rules

- **Diagnose before fixing** — explain possible causes before changing code
- **50-line function limit** — break larger functions into focused helpers
- **Single responsibility** — one job per function and module
- **Descriptive names** — `calculateInvoiceTotal` not `calc`
- **No dead code** — remove commented-out code and debug statements before completing
- **No silent failures** — never swallow exceptions without handling or logging
- **Justify dependencies** — do not add packages without strong justification
- **Tests before done** — always run tests before marking any task complete
