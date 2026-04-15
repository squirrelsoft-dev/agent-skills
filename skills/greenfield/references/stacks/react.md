# React Stack Reference

Loaded by SKILL.md Step 3 when `STACK` is `react`.

---

## Command Mapping

Resolve env vars using `PKG_MANAGER` as the column key:

| Env var | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `INSTALL_CMD` | `npm install` | `pnpm install` | `yarn install` | `bun install` |
| `DEV_CMD` | `npm run dev` | `pnpm dev` | `yarn dev` | `bun dev` |
| `BUILD_CMD` | `npm run build` | `pnpm build` | `yarn build` | `bun run build` |

### TEST_CMD by TEST_RUNNER

| TEST_RUNNER | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `vitest` | `npx vitest run` | `pnpm vitest run` | `yarn vitest run` | `bun vitest run` |
| `jest` | `npx jest` | `pnpm jest` | `yarn jest` | `bun jest` |
| `mocha` | `npx mocha` | `pnpm mocha` | `yarn mocha` | `bun mocha` |
| (none) | `echo 'no tests configured'` | `echo 'no tests configured'` | `echo 'no tests configured'` | `echo 'no tests configured'` |

### LINT_CMD by FORMATTER

> React has no built-in lint command. Fall back to `eslint .` if eslint is present, otherwise use the formatter directly.

| FORMATTER | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `prettier` (default) | `npx eslint .` | `pnpm eslint .` | `yarn eslint .` | `bun eslint .` |
| `biome` | `npx biome check .` | `pnpm biome check .` | `yarn biome check .` | `bun biome check .` |

---

## Framework Details

- No built-in lint command — use `eslint .` if eslint is present
- Build output depends on bundler: Vite → `dist/`, CRA → `build/`
- `DEV_CMD` is `$PKG_MANAGER run dev` (both Vite and CRA use this)
- Add the build output directory to `.gitignore`

---

## Directory Structure

```
src/
  components/           # Shared UI components
  pages/ or routes/     # Page-level components or route definitions
  lib/                  # Utilities, helpers, data fetching
public/                 # Static assets
```

---

## Conventions

- TypeScript strict mode expected (`strict: true` in tsconfig.json)
- Prefer named exports for components
- Components should be focused and composable — one job per component
- Co-locate styles, types, and tests with their component
- Use React Router or TanStack Router for routing (no file-based routing)
- All components are client-side — no Server Components outside Next.js

---

## Key Dependencies

- react, react-dom
- typescript, @types/react
- vite or react-scripts (bundler)
- eslint, eslint-plugin-react-hooks
- vitest or jest (testing)
- tailwindcss (common but not required)

---

## Stop-Hook Quality Gate

Same as the TypeScript/Node stack: scoped to changed files only, using
`oxlint` for lint, `oxfmt --check` for working-set format, `turbo run
typecheck` (monorepo) or `tsc --noEmit` (single package) for types, and
`vitest related` / `jest --findRelatedTests` for tests. Dependency audit
runs only when `package.json` changes. See `typescript-node.md` for the
full table.
