---
description: 'Find and install skills for your project dependencies. Reads installed skills and dependency files, identifies gaps, and guides the user through discovery and installation.'
---

# Update Skills

Checks for skills relevant to this project's dependencies that aren't installed yet.

## Step 1 — Read installed skills

```bash
npx skills list
```

Note each installed skill's name and description. Infer what packages each skill
covers — a skill named `prisma-best-practices` covers `prisma`, a skill named
`playwright-testing` covers `playwright`. Use judgment, not exact string matching:
a skill called `react-patterns` likely covers both `react` and `react-dom`.

## Step 2 — Read project dependencies

Detect the stack and read the appropriate dependency file(s):

- **Node/TypeScript**: `package.json` — both `dependencies` and `devDependencies`
- **Python**: `pyproject.toml` or `requirements.txt`
- **Go**: `go.mod` direct dependencies
- **Rust**: `Cargo.toml` direct dependencies

Identify **meaningful packages** — frameworks, ORMs, UI libraries, testing tools,
build tools, infrastructure clients. Filter out noise:

- `@types/*` packages
- Transitive-only dependencies
- Low-level utilities (lodash, uuid, date-fns, clsx, etc.)
- Anything clearly already covered by an installed skill

## Step 3 — Identify gaps

Cross-reference meaningful packages against installed skills. Produce a list of
packages that are actively used but not covered by any installed skill.

This is a judgment call. A skill may cover multiple related packages. Do not
require exact name matching — reason about what each skill covers.

If all packages are already covered, report this and stop:
> "All your key dependencies are covered by installed skills. Nothing to add."

## Step 4 — Present findings and suggest discovery

Show the analysis:

```
📦 Dependencies not covered by any installed skill:

  prisma, playwright, tailwindcss, zustand, zod

✅ Already covered by installed skills:
  react, next → next-patterns
  vitest → testing-patterns

To search for skills for these dependencies, run:
  /find-skills prisma
  /find-skills playwright
  /find-skills tailwindcss

Or search for all at once:
  /find-skills prisma playwright tailwindcss zustand zod
```

If no uncovered packages are found, report this clearly. Do not install skills
directly — present the gaps and let the user decide which to search for.

## Edge cases

- **npx not available** — print a clear error and stop.
- **No dependency file found** — report which files were checked and stop.
- **All packages already covered** — brief confirmation in Step 3, stop.
- **No uncovered packages** — report clearly, skip Step 4.
