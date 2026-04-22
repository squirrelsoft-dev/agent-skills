# agent-skills

Claude Code agent skills for intelligent, interview-driven project configuration. Replaces the deterministic [cc-toolkit](https://github.com/squirrelsoft-dev/cc-toolkit) scripts with adaptive skills that detect your stack, ask the right questions, and generate tailored Claude Code configuration.

## Skills

| Skill | Description | Status |
|---|---|---|
| **greenfield** | Set up Claude Code for a brand new project from scratch | ✅ Available |
| **workflow** | Install development commands and agent workflows | ✅ Available |
| **brownfield** | Analyze and configure Claude Code for an existing project | In progress |

## Installation

Install a skill using [open-agent-skills](https://agentskills.io):

```bash
npx skills add squirrelsoft-dev/agent-skills@greenfield
npx skills add squirrelsoft-dev/agent-skills@workflow
```

The package handles placing the skill in the correct directory for your Claude Code installation.

## What gets generated

### `greenfield`

Runs an interactive interview, detects your stack, then generates:

- `CLAUDE.md` — project context for Claude Code
- `.claude/settings.json` — hooks and agent configuration
- `.claude/settings.local.json` — stack-specific permissions
- `.claude/rules/` — coding rules (general, security, testing, stack-specific)
- `.claude/hooks/` — guard rails, auto-formatting, scoped stop-hook quality gate
- `.gitignore` entries for Claude Code personal files

For JavaScript/TypeScript projects, the default linter/formatter is [**oxlint** + **oxfmt**](https://oxc.rs) (ESLint/Prettier-compatible, much faster). Existing `.prettierrc` or `biome.json` configs are still respected.

### `workflow`

Installs slash commands, agents, and (optionally) the triage skill. At install time you pick one of three orchestration modes:

| Mode | How it works | When to use |
|---|---|---|
| **Subagents — PEE loop** (recommended) | Per spec, a Planner → Executor → Evaluator loop runs on a shared branch; one final 8-gate quality pass at the end. One-shot subagents, no team infrastructure. Opus planner, Sonnet evaluator, Haiku executor. | Best spec-compliance correctness; safe default for most projects. |
| **Subagents — parallel** | Parallel workers in isolated git worktrees, merged by the git-expert agent. | Stable, works everywhere, maximum throughput on independent work. |
| **Agent teams** (experimental) | Persistent teammates own parallel domains on a shared branch, with a dedicated Quality Gate agent between groups. Requires CC v2.1.32+ and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. | Large, multi-domain features where team ownership maps to codebase areas. |

Commands installed: `/breakdown`, `/spec`, `/work`, `/commit`, `/review`, `/pr`, `/squash-pr`, `/address-pr-comments`, `/fix-issue`, `/security-scan`, `/update-skills`. The `triage` skill (GitHub issue triage) is installed alongside.

Agents installed vary by mode but include `planner`, `executor`, `evaluator`, `quality`, `architect`, `manager`, and `git-expert`.

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
