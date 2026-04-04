# agent-skills

Claude Code agent skills for intelligent, interview-driven project configuration. Replaces the deterministic [cc-toolkit](https://github.com/squirrelsoft-dev/cc-toolkit) scripts with adaptive skills that detect your stack, ask the right questions, and generate tailored Claude Code configuration.

## Skills

| Skill | Description | Status |
|---|---|---|
| **greenfield** | Set up Claude Code for a brand new project from scratch | In progress |
| **brownfield** | Analyze and configure Claude Code for an existing project | Planned |
| **workflow** | Install development commands and agent workflows | Planned |

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

## Supported Stacks

- Next.js / React
- Node.js / TypeScript
- Python (FastAPI, Django, Flask)
- Go
- Rust
- .NET

## Documentation

- [Agent Skills Specification](https://agentskills.io)
- [Greenfield Implementation Plan](docs/greenfield-implementation-plan.md)

## License

MIT
