# api.md

**Rule file:** `.claude/rules/api.md`  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)  
**Applies to:** `src/api/**`, `app/api/**`, `src/routes/**`, `src/server/**`  
**Stacks:** nextjs, react, typescript-node

API design rules applied when Claude is working in route or server files.

## Rules

- **Validate all input** — use zod or equivalent; reject invalid input at the boundary
- **Consistent error shapes** — return structured errors with appropriate HTTP status codes
- **No internal leakage** — never expose stack traces or internal error messages in production responses
- **Rate limiting** — include rate limiting on all public-facing endpoints
