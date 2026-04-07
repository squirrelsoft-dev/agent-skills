# agent-skills

Claude Code agent skills for intelligent, interview-driven project configuration. Replaces the deterministic [cc-toolkit](https://github.com/squirrelsoft-dev/cc-toolkit) scripts with adaptive skills that detect your stack, ask the right questions, and generate tailored Claude Code configuration.

## Skills

| Skill | Description | Status |
|---|---|---|
| **greenfield** | Set up Claude Code for a brand new project from scratch | ✅ Available |
| **brownfield** | Analyze and configure Claude Code for an existing project | In progress |
| **workflow** | Install development commands and agent workflows | In progress |

## Installation

Install a skill using [open-agent-skills](https://agentskills.io):

```bash
npx skills add squirrelsoft-dev/agent-skills@greenfield
```

The package handles placing the skill in the correct directory for your Claude Code installation.

## What gets generated

The **greenfield** skill runs an interactive interview, detects your stack, then generates:

- `CLAUDE.md` — project context for Claude Code
- `.claude/settings.json` — hooks and agent configuration
- `.claude/settings.local.json` — stack-specific permissions
- `.claude/rules/` — coding rules (general, security, testing, stack-specific)
- `.claude/hooks/` — guard rails, auto-formatting, quality gates
- `.gitignore` entries for Claude Code personal files

The **workflow** skill adds slash commands (`/breakdown`, `/spec`, `/work`, etc.) and agents in two orchestration modes: **subagents** (parallel workers in isolated worktrees) or **agent teams** (persistent domain teammates with group-based execution and a dedicated Quality Gate agent).

## Supported Stacks

- Next.js / React
- Node.js / TypeScript
- Python (FastAPI, Django, Flask)
- Go
- Rust
- .NET

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core) (auto-installed on first run):

```bash
bash tests/greenfield/run-tests.sh
bash tests/workflow/run-tests.sh
```

Tests cover stack detection, artifact generation, hook behavior, and full end-to-end scenarios.

## Documentation

- [Agent Skills Specification](https://agentskills.io)
- [Greenfield Implementation Plan](docs/greenfield-implementation-plan.md)
- [Workflow Implementation Plan](docs/workflow-implementation-plan.md)
- [Full documentation index](docs/README.md)

## License

MIT
