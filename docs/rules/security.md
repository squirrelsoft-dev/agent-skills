# security.md

**Rule file:** `.claude/rules/security.md`  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)  
**Applies to:** All files (no path scope)

Security practices that apply across all code Claude writes or modifies.

## Rules

- **No hardcoded secrets** — never embed API keys, credentials, or tokens; use environment variables
- **Validate at the boundary** — validate all external input before use
- **Parameterized queries** — never interpolate user input into SQL; use ORMs or parameterized queries
- **Sanitize output** — sanitize anything that reaches HTML or templates
- **No sensitive logs** — never log passwords, tokens, or PII
