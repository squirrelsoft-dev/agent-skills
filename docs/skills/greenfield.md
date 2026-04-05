# Greenfield Skill

Configures Claude Code for a **brand new project** — one that doesn't have a `.claude/` directory yet. It detects your stack, asks a short set of questions, then generates all the configuration files Claude Code needs to work effectively in your project.

## Installation

```bash
npx skills add squirrelsoft-dev/agent-skills@greenfield
```

## Trigger

Once installed, trigger it in Claude Code with any of:

- `/greenfield`
- "set up Claude Code for this project"
- "initialize Claude"
- "run greenfield setup"
- "configure Claude for this project"

---

## What it does

The greenfield skill runs in 8 steps:

### Step 1 — Preflight
Checks whether a `.claude/` directory already exists. If it does, asks whether to overwrite or abort.

### Step 2 — Stack Detection
Runs `detect-stack.sh` against the current directory to identify:

| Detected value | How |
|---|---|
| Stack (nextjs, react, typescript-node, python, go, rust, dotnet) | Presence of package.json, go.mod, Cargo.toml, etc. |
| Framework | Dependencies in package.json or requirements.txt |
| Language | TypeScript detection via tsconfig.json |
| Package manager | Lockfile presence (bun.lockb, pnpm-lock.yaml, yarn.lock) |
| Formatter | biome.json, .prettierrc, etc. |
| Test runner | vitest, jest, mocha in package.json; pytest, go test, cargo test by stack |

Outputs a JSON object passed as environment variables to all generator scripts.

### Step 3 — Developer Interview
Loads `references/interview.md` and presents all questions at once. Waits for a single response before proceeding.

| Question | Env var set |
|---|---|
| Project name | `PROJECT_NAME` |
| Project description | `PROJECT_DESCRIPTION` |
| Confirm/correct detected stack | `STACK`, `PKG_MANAGER`, etc. |
| Git setup (init / already done / skip) | `GIT_SETUP` |
| Enable agent teams? | `AGENT_TEAMS` |
| Commit style (conventional / free-form) | `COMMIT_STYLE` |
| Scaffold GitHub Actions CI? | `CI_CD`, `CI_WORKFLOWS` |

### Step 4 — Load Stack Knowledge
Reads the appropriate stack reference file from `references/stacks/` (nextjs.md, typescript-node.md, python.md, go.md) to inform artifact generation with stack-specific conventions.

### Step 5 — Generate Artifacts
Runs all generator scripts in parallel if agent teams are available, otherwise sequentially. Each script is independent and idempotent.

### Step 6 — Git Setup
If `GIT_SETUP=init`: runs `git init` and creates a first commit containing all generated files.

### Step 7 — CI/CD Scaffold
If `CI_CD=yes`: loads `references/ci-templates.md` and writes `.github/workflows/` files for the selected workflows (lint, test, build, deploy).

### Step 8 — Completion Summary
Lists all generated files and prints next steps, including the command to install the workflow skill.

---

## Artifacts created

All artifacts are written into the project directory. None are written into the skill directory itself.

### Foundation files

| File | Description |
|---|---|
| `CLAUDE.md` | Project overview, commands, and conventions for Claude to read at session start |
| `.gitignore` additions | Appends Claude-specific entries (`CLAUDE.local.md`, `.claude/settings.local.json`, `.claude/logs/`, etc.) |

### `.claude/settings.json`

Configures all hooks and optionally enables agent teams. See the [hooks documentation](#hooks) for what each hook does.

### `.claude/settings.local.json`

Stack-specific command allowlist so Claude doesn't need to ask permission for common operations (e.g. `npm install`, `pytest`, `go test`).

### Hooks

Written to `.claude/hooks/`. All scripts are `chmod +x`.

| File | Doc | Purpose |
|---|---|---|
| `guard.sh` | [→ guard](../hooks/guard.md) | Blocks destructive commands before execution |
| `format.sh` | [→ format](../hooks/format.md) | Auto-formats files after Claude writes them |
| `stop-quality-gate.sh` | [→ stop-quality-gate](../hooks/stop-quality-gate.md) | Runs lint + tests before Claude marks a task complete |
| `task-summary.sh` | [→ task-summary](../hooks/task-summary.md) | Logs session activity to `.claude/logs/` |
| `save-context.sh` | [→ save-context](../hooks/save-context.md) | Saves WIP snapshot before context compaction |
| `session-start.sh` | [→ session-start](../hooks/session-start.md) | Shows git state when a session opens |

### Rules

Written to `.claude/rules/`. Which files are created depends on the detected stack.

| File | Doc | Created for |
|---|---|---|
| `general.md` | [→ general](../rules/general.md) | All stacks |
| `security.md` | [→ security](../rules/security.md) | All stacks |
| `testing.md` | [→ testing](../rules/testing.md) | All stacks |
| `frontend.md` | [→ frontend](../rules/frontend.md) | nextjs, react |
| `api.md` | [→ api](../rules/api.md) | nextjs, react, typescript-node |

---

## Supported stacks

| Stack | Detected by | Formatter | Test runner |
|---|---|---|---|
| `nextjs` | `"next"` in package.json | biome or prettier | vitest or jest |
| `react` | `"react"` in package.json | biome or prettier | vitest or jest |
| `typescript-node` | express/fastify/hono or plain package.json | biome or prettier | vitest, jest, or mocha |
| `python` | requirements.txt or pyproject.toml | ruff | pytest |
| `go` | go.mod | gofmt | go test |
| `rust` | Cargo.toml | rustfmt | cargo test |
| `dotnet` | *.csproj | dotnet-format | dotnet test |
| `unknown` | None of the above | none | none |

---

## After greenfield

Greenfield sets up the foundation. To install the development command layer (slash commands and agents), run the workflow skill next:

```bash
npx skills add squirrelsoft-dev/agent-skills@workflow
```

Then in Claude Code: `/workflow`

→ [Workflow skill documentation](workflow.md)
