---
description: 'Find and install skills for your project dependencies. Reads installed skills and dependency files, identifies gaps, searches the registry, and offers to install matches.'
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

## Step 4 — Search the registry

For each uncovered package, run:

```bash
npx skills find <package-name>
```

Use parallel subagents to run searches concurrently — a project might have 10-15
uncovered packages worth searching. Collect and deduplicate results across all
searches (the same skill might match multiple packages).

## Step 5 — Present findings

Show three groups:

```
📦 Skills found for your dependencies:

  prisma        → prisma-best-practices     "Prisma ORM patterns, migrations, and query optimization"
  playwright    → playwright-testing        "E2E testing patterns and best practices with Playwright"
  tailwindcss   → tailwind-ui-patterns      "Tailwind CSS component patterns and design system usage"

✅ Already covered by installed skills:
  react, next → next-patterns
  vitest → testing-patterns

🔍 No skills found for:
  zustand, zod, lucide-react
  (These packages don't have skills in the registry yet — see https://skills.sh)

Install the N found skills? (all / select / none)
```

If no skills were found for any uncovered package, report this clearly and mention
https://skills.sh as a place to discover or contribute skills. Do not make the
"nothing found" cases feel like failures — the registry is growing.

## Step 6 — Install selected skills

For each approved skill:

```bash
npx skills add <skill-name>
```

After installation:
> "⚠️ Restart Claude Code to load the new skills into context."

## Edge cases

- **npx not available** — print a clear error and stop.
- **No dependency file found** — report which files were checked and stop.
- **All packages already covered** — brief confirmation in Step 3, skip Steps 4-6.
- **No skills found for any uncovered package** — report clearly in Step 5, skip Step 6.
