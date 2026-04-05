# Brownfield Skill

> 🚧 This skill is currently in development.

Configures Claude Code for an **existing codebase** by discovering what's already there — conventions, architecture, testing patterns, git workflow — then generating tailored configuration from those findings.

Unlike the greenfield skill, conventions are **detected** from the actual project rather than defined in an interview.

## Installation

```bash
npx skills add squirrelsoft-dev/agent-skills@brownfield
```

## Trigger

- `/brownfield`
- "set up Claude Code for this project"
- "onboard Claude to this repo"
- "analyze this codebase for Claude"

---

## What it does

### Phase 1 — Parallel Analysis (read-only)
Runs four analysis scripts in parallel. No files are written in this phase.

| Script | Detects |
|---|---|
| `analyze-repo.sh` | Stack, framework, package manager, formatter, lint/test/build/dev commands |
| `analyze-conventions.sh` | File naming, import style, quote style, semicolons, path aliases, org structure |
| `analyze-git.sh` | Commit style (70%+ conventional → detected as conventional), branch naming, CI platform, recent commits |
| `analyze-tests.sh` | Test framework, file locations (co-located vs separate), factories, fixtures, MSW |

### Phase 2 — Human Review Checkpoint
Synthesizes findings into a structured summary and asks for confirmation before writing anything. Surfaces conflicts and ambiguities for human resolution.

### Phase 3 — Generate Artifacts
Same artifact set as greenfield, but populated with **real detected values** rather than defaults.

---

## Artifacts created

Same set as the [greenfield skill](greenfield.md#artifacts-created) — `CLAUDE.md`, hooks, rules, settings — but content reflects the actual codebase conventions discovered during analysis.

---

## After brownfield

```bash
npx skills add squirrelsoft-dev/agent-skills@workflow
```

Then in Claude Code: `/workflow`

→ [Workflow skill documentation](workflow.md)
