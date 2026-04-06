# Architectural Analysis Guide

Instructions for Claude's codebase analysis in brownfield Step 3b.
Use the Explore subagent (`context: fork`) to read the codebase and identify
patterns that script-based analysis cannot detect.

Use the analysis JSON from Step 2 as a starting point — the confirmed stack,
org pattern, and file locations tell you where to look.

---

## What to Investigate

### 1. Dependency and Call Patterns

Trace how the codebase is actually wired:

- How do components/modules get data? Direct fetch, hooks, a service layer, a store?
- Is there a centralized HTTP client (e.g. `src/lib/api/client.ts`)? Or do files call fetch/axios directly?
- Are there utility modules that everything imports from? Are there modules nothing imports from (dead code)?
- What does the import graph look like — circular dependencies, layer violations?

**Glob patterns to check:** `**/api/**`, `**/client.*`, `**/services/**`, `**/hooks/use*`

### 2. Architectural Boundaries

- What are the top-level directories in `src/` and what is each responsible for?
- Are there directories that are clearly "don't touch" (legacy, deprecated, vendor)?
- Is there a layer pattern (controllers → services → repositories) consistently followed?
- Are there "God files" that import half the codebase?

**Glob patterns to check:** `src/*/`, `src/*/index.*`, `**/legacy/**`, `**/deprecated/**`

### 3. Error Handling Patterns

- How are errors handled? Try/catch everywhere, centralized handler, error boundaries, Result types?
- Are there custom error classes? Are they used consistently?
- Do API errors have a consistent response shape?

**Grep patterns:** `class.*Error`, `catch`, `ErrorBoundary`, `throw new`, `Result<`

### 4. Auth and Permissions Patterns

- How is auth checked? Middleware, HOC, guards, decorators?
- Are there protected routes and how are they declared?
- Is there role-based access and where does that logic live?

**Grep patterns:** `auth`, `guard`, `middleware`, `protect`, `permission`, `role`

### 5. State Management Patterns

Applicable mainly to frontend projects (React, Next.js):

- Where does state live — component, context, store, server state (React Query/SWR)?
- Are there conventions around when to use local vs global state?
- How is async state handled (loading/error/success)?

**Grep patterns:** `useQuery`, `useSWR`, `createContext`, `createStore`, `zustand`, `redux`

### 6. Testing Patterns Beyond Framework

- Do tests use a consistent arrange/act/assert structure?
- Are there shared test utilities, custom matchers, or test factories?
- What gets mocked and how — jest.mock, MSW, manual mocks, dependency injection?
- Are there integration tests alongside unit tests?

**Glob patterns:** `**/__mocks__/**`, `**/factories/**`, `**/test-utils.*`, `**/setup.*`

### 7. Git History Patterns (if gh CLI available)

- What files change together most often? (co-change patterns → coupling rules)
- Which areas have the most bug fixes? (high churn → caution rules)
- What do recent PR descriptions mention? (recurring concerns → explicit rules)

**Commands:** `git log --format="%H" -50 | ...`, `gh pr list --limit 10 --json title,body`

---

## How to Express Findings as Rules

### Rule File Format

Generated rules use the same frontmatter + markdown format as standard rules:

```markdown
---
paths:
  - "src/features/**"
---
# Feature Module Rules

## Data Fetching
All API calls go through `src/lib/api/client.ts`. Never call fetch or axios
directly from components or hooks.
```

### Naming Conventions for Generated Files

Choose descriptive names based on what was found:

| Pattern Found | File Name |
|---|---|
| Clear architectural layers | `architecture.md` |
| Legacy/frozen directories | `legacy.md` |
| Project-specific traps | `gotchas.md` |
| Data fetching conventions | `data-fetching.md` |
| Auth patterns | `auth.md` |

### Writing Good Rules

- **Be specific:** "All API calls go through `src/lib/api/client.ts`" not "Use centralized API calls"
- **Include file paths:** Reference actual files the developer can find
- **Explain why:** "The client handles auth headers and retry logic" not just "don't use fetch"
- **Use path-scoped frontmatter:** Apply rules only to relevant directories

### What NOT to Generate

- Generic advice that applies to any project (that belongs in `general.md`)
- Rules that duplicate what's already in `conventions.md` or `testing.md`
- Rules based on patterns found in only 1-2 files (not enough evidence)
- Rules about code style or formatting (handled by `conventions.md`)

---

## Developer Review Protocol

After generating additional rules, present them for review before writing:

1. Show the file name and a 2-3 line summary of what each file covers
2. Show the first few lines of each file as a preview
3. Ask the developer to:
   - **Accept all** — write all files and proceed
   - **Edit** — modify specific rules before writing
   - **Skip** — omit specific files

Never write architectural rules without developer confirmation. Claude's
inferences may be wrong — a pattern that looks intentional might be accidental,
and gotchas that look like bugs might be intentional workarounds.
