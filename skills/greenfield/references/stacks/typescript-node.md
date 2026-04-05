# TypeScript / Node.js Stack Reference

Loaded by SKILL.md Step 4 when `STACK` is `typescript-node`.

---

## Command Mapping

Resolve env vars using `PKG_MANAGER` as the column key:

| Env var | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `INSTALL_CMD` | `npm install` | `pnpm install` | `yarn install` | `bun install` |
| `DEV_CMD` | `npx tsx watch src/index.ts` | `pnpm tsx watch src/index.ts` | `yarn tsx watch src/index.ts` | `bun --watch src/index.ts` |
| `BUILD_CMD` | `npx tsc` | `pnpm tsc` | `yarn tsc` | `bun build src/index.ts --outdir dist` |
| `LINT_CMD` | `npx eslint .` | `pnpm eslint .` | `yarn eslint .` | `bun eslint .` |

> **Note:** If package.json defines a `"dev"` script, prefer `$PKG_MANAGER run dev` over the `tsx watch` default.

### TEST_CMD by TEST_RUNNER

| TEST_RUNNER | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `vitest` | `npx vitest run` | `pnpm vitest run` | `yarn vitest run` | `bun vitest run` |
| `jest` | `npx jest` | `pnpm jest` | `yarn jest` | `bun jest` |
| `mocha` | `npx mocha` | `pnpm mocha` | `yarn mocha` | `bun mocha` |
| (none) | `echo 'no tests configured'` | `echo 'no tests configured'` | `echo 'no tests configured'` | `echo 'no tests configured'` |

---

## Framework Variants

### FRAMEWORK=node-api (express / fastify / hono)
- Entry point is typically `src/index.ts` or `src/server.ts`
- `DEV_CMD` should use `tsx watch` for hot reload during development
- Build produces `dist/` — run with `node dist/index.js` in production

### FRAMEWORK=node (library / CLI)
- Entry point may be `src/index.ts` (library) or `src/cli.ts` (CLI tool)
- `DEV_CMD` may not apply — use `tsx watch` if there's a runnable entry point
- Build typically uses `tsup` or `tsc` to produce `dist/`

### FORMATTER override
- If `FORMATTER=biome`, replace `eslint .` with `biome check .` in `LINT_CMD`

---

## Directory Structure

```
src/                  # Source code
  index.ts            # Entry point
  routes/             # API routes (node-api)
  lib/                # Shared utilities
dist/                 # Compiled output (gitignored)
tests/                # Test files
```

---

## Conventions

- ESM by default (`"type": "module"` in package.json)
- TypeScript strict mode (`strict: true` in tsconfig.json)
- Use `tsx` for development, `tsc` (or `tsup`) for production builds
- Prefer `node:` prefix for built-in modules (e.g., `node:fs`, `node:path`)
- Add `dist/` and `node_modules/` to `.gitignore`

---

## Key Dependencies

- typescript, @types/node, tsx
- eslint or @biomejs/biome
- vitest or jest (testing)
- tsup (optional — bundler for libraries)
- express / fastify / hono (if FRAMEWORK=node-api)
