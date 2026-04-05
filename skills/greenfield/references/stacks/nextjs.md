# Next.js Stack Reference

Loaded by SKILL.md Step 3 when `STACK` is `nextjs`.

---

## Command Mapping

Resolve env vars using `PKG_MANAGER` as the column key:

| Env var | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `INSTALL_CMD` | `npm install` | `pnpm install` | `yarn install` | `bun install` |
| `DEV_CMD` | `npm run dev` | `pnpm dev` | `yarn dev` | `bun dev` |
| `BUILD_CMD` | `npm run build` | `pnpm build` | `yarn build` | `bun run build` |
| `LINT_CMD` | `npm run lint` | `pnpm lint` | `yarn lint` | `bun run lint` |

### TEST_CMD by TEST_RUNNER

| TEST_RUNNER | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `vitest` | `npx vitest run` | `pnpm vitest run` | `yarn vitest run` | `bun vitest run` |
| `jest` | `npx jest` | `pnpm jest` | `yarn jest` | `bun jest` |
| `mocha` | `npx mocha` | `pnpm mocha` | `yarn mocha` | `bun mocha` |
| (none) | `echo 'no tests configured'` | `echo 'no tests configured'` | `echo 'no tests configured'` | `echo 'no tests configured'` |

### LINT_CMD by FORMATTER

> The default row assumes `package.json` defines `"lint": "next lint"` (Next.js default). If no lint script exists, fall back to `npx eslint .`.

| FORMATTER | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| `prettier` (default) | `npm run lint` | `pnpm lint` | `yarn lint` | `bun run lint` |
| `biome` | `npx biome check .` | `pnpm biome check .` | `yarn biome check .` | `bun biome check .` |

---

## Framework Details

- `LINT_CMD` table assumes `package.json` defines `"lint": "next lint"` (Next.js default). If no lint script exists, fall back to `npx eslint .`
- Build output: `.next/`
- Add `.next/` to `.gitignore`

---

## Directory Structure

```
app/                  # App Router routes (layout.tsx, page.tsx, loading.tsx)
components/           # Shared UI components
lib/                  # Utilities, helpers, data fetching
public/               # Static assets
```

---

## Conventions

- App Router is the default for new Next.js projects
- Components are Server Components by default — add `"use client"` only when needed
- TypeScript strict mode expected (`strict: true` in tsconfig.json)
- Path alias `@/` maps to project root (e.g., `@/components/Button`)
- Collocate route-specific components inside `app/` route folders
- Prefer named exports for components

---

## Key Dependencies

- next, react, react-dom
- typescript, @types/react, @types/node
- tailwindcss (common but not required)
- eslint-config-next (Next.js lint preset)
- vitest or jest (testing)
