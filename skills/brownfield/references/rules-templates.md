# Rules Content Guidelines

Guidelines for generating `.claude/rules/*.md` files from brownfield analysis.
Rules must contain **real examples from the codebase** — never generic placeholders.

---

## File: general.md

Universal code quality rules. Same for all stacks:

- Diagnose before fixing
- Function length limits (50 lines max)
- Single responsibility
- No commented-out code or debug statements
- No swallowed exceptions
- No unnecessary dependencies
- Always run tests before completing

This file is stack-agnostic and does not use detected values.

---

## File: conventions.md

**Every rule must reference a real detected value.** Do not write generic advice.

### File Naming
Use the detected `file_naming` value. Express as an actionable rule:
- Good: "Files use kebab-case naming: `user-profile.ts`, not `UserProfile.ts`"
- Bad: "Use consistent file naming"

If `file_naming` is "unknown", write: "No dominant file naming pattern detected — match the style of surrounding files."

### Import Style
Use the detected `import_style` and `path_aliases` values:
- Good: "Use absolute imports with `@/` alias: `import { Button } from '@/components/Button'`"
- Bad: "Use consistent imports"

### Formatting
Use detected `quote_style` and `semicolons`:
- Good: "Single quotes, no semicolons — enforced by Biome"
- Bad: "Follow the project's formatting style"

### Key Rule
Always include: "Match the style of surrounding files when making changes."

---

## File: testing.md

### Frontmatter (path-scoped)
Use detected `file_location` to set frontmatter paths:
- Co-located: `paths: ["**/*.test.*", "**/*.spec.*"]`
- Separate directory: `paths: ["tests/**", "__tests__/**"]`

### Framework
State the detected framework explicitly:
- Good: "Tests use Vitest with `@testing-library/react`"
- Bad: "Use the project's test framework"

### Test Run Command
Use the real detected command:
- Good: "`pnpm test -- --passWithNoTests`"
- Bad: "Run the test command"

### Rules
Standard testing rules apply to all stacks:
- Test behavior, not implementation
- Include edge cases
- Descriptive test names
- Mock external services

---

## File: security.md

Universal security rules. Same for all stacks:

- No hardcoded secrets
- Validate external input at boundaries
- Parameterized queries only
- Sanitize HTML output
- Never log sensitive data

This file is stack-agnostic and does not use detected values.

---

## Handling Unknown Values

When a detection returns "unknown":
1. Do NOT omit the section — include it with a fallback
2. Use the phrase: "No [X] pattern detected — match surrounding code"
3. Never invent a convention that wasn't detected

Example:
```markdown
## Import Style
No dominant import pattern detected — match the style of surrounding files.
```
