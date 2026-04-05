# frontend.md

**Rule file:** `.claude/rules/frontend.md`  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)  
**Applies to:** `src/components/**`, `src/app/**`, `app/**`, `pages/**`  
**Stacks:** nextjs, react

Frontend-specific rules applied when Claude is working in component or page files.

## Rules

- **Focused components** — one job per component; extract subcomponents when a file approaches 200 lines
- **Loading and error states** — always include both; never leave UI in an indeterminate state
- **Accessibility** — use semantic HTML and ARIA attributes
- **No prop drilling** — avoid passing props more than 2 levels deep; use context or state management
- **Co-location** — keep styles, types, and tests alongside their component
