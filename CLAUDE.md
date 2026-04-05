# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

agent-skills is a collection of Claude Code agent skills that replace the deterministic cc-toolkit with interview-driven, stack-aware project configuration. Skills are distributed via `npx skills add squirrelsoft-dev/agent-skills@<skill-name>`.

## Skills

| Skill | Purpose | Status |
|---|---|---|
| **greenfield** | Configure Claude Code for a brand new project | In progress |
| **brownfield** | Analyze an existing codebase and generate Claude Code config | Planned |
| **workflow** | Install development commands and agent workflows | Planned |

## Architecture

Each skill follows the [open-agent-skills](https://agentskills.io) spec:

```
skills/<skill-name>/
├── SKILL.md              ← orchestrator (frontmatter: name, description; body: step-by-step instructions)
├── scripts/              ← executable shell scripts called by SKILL.md
└── references/           ← markdown knowledge files loaded at runtime
```

- `SKILL.md` must stay under 500 lines. Heavy content goes in `references/`.
- The `name` frontmatter field must match the directory name exactly (lowercase, hyphens only).
- All `.sh` files must be executable (`chmod +x`).
- Scripts output JSON status to stdout and log messages to stderr.
- Scripts receive configuration via environment variables, not arguments.

## Greenfield Pipeline

The greenfield skill runs 8 steps: preflight → stack detection → developer interview → load stack knowledge → generate artifacts (settings, rules, hooks, CLAUDE.md, .gitignore) → git setup → CI/CD → completion summary. Each generator script is independent and can run in parallel.

## Brownfield Pipeline

The brownfield skill runs 4 analysis scripts in parallel (repo, conventions, git, tests), presents findings for human review with conflict resolution, then generates the same output artifacts as greenfield.

## Implementation Plans

Detailed specs for each skill live in `docs/`. These are the source of truth — script content and orchestration flow are defined there.

## Testing

Greenfield skill tests use [bats-core](https://github.com/bats-core/bats-core) (auto-installed on first run). Run all tests:

```bash
bash skills/greenfield/tests/run-tests.sh
```

Tests are split into `unit/` (one `.bats` file per script) and `e2e/` (full pipeline per scenario: nextjs, python, empty, existing-claude). Each test runs in a fresh `mktemp -d` directory. Fixtures live in `tests/fixtures/`.

## Conventions

- Shell scripts use `set -e` and read inputs from environment variables
- Scripts that generate files create the target directory with `mkdir -p` first
- Generator scripts are idempotent where possible (e.g., gitignore checks for existing entries)
- Stack reference files in `references/stacks/` contain conventions, commands, and directory structures per framework
