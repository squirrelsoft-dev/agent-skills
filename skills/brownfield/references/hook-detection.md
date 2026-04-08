# Hook Detection & Recommendation Logic

Decision logic for which hooks to install based on brownfield analysis findings.
Used during the human review checkpoint (Step 3) to explain what will be generated.

---

## Always Installed

These hooks are installed for every project regardless of analysis results:

| Hook | Event | Purpose |
|---|---|---|
| `guard.sh` | PreToolUse (Bash) | Blocks destructive commands (rm -rf /, DROP TABLE, force push, secret exposure) |
| `task-summary.sh` | Stop | Writes session log to `.claude/logs/` |
| `save-context.sh` | PreCompact | Saves WIP snapshot to `.claude/scratch/` before context compression |
| `session-start.sh` | SessionStart | Displays git state at session start (skips for subagents/teammates) |

---

## Conditional: format.sh

**Event:** PostToolUse (Write|Edit|MultiEdit)

Install when a formatter is detected. The formatter command varies by stack:

| Detected `formatter` | Command |
|---|---|
| `biome` | `npx @biomejs/biome format --write "$FILE"` |
| `prettier` | `npx prettier --write "$FILE"` |
| `ruff` | `ruff format "$FILE"` (fallback: `black "$FILE"`) |
| `gofmt` | `gofmt -w "$FILE"` |
| `rustfmt` | `rustfmt "$FILE"` |
| `dotnet-format` | `dotnet format "$FILE"` |

If no formatter detected, defaults to Prettier.

**Checkpoint display:** "Auto-format on file write using [formatter]"

---

## Conditional: stop-quality-gate.sh

**Event:** Stop, SubagentStop

Install when `lint_cmd` OR `test_cmd` is detected. Runs both on changed files before allowing task completion.

The `# Lint` comment in the generated script is a **required landmark** — the workflow skill's `patch-quality-gate.sh` uses it as an insertion point for security scan blocks (gitleaks, semgrep).

**Checkpoint display:** "Quality gate runs `[lint_cmd]` and `[test_cmd]` on changed files before task completion"

---

## Conditional: Agent Teams TaskCompleted Hook

**Event:** TaskCompleted

Install **only** when the developer confirms `agent_teams = true` at the checkpoint.

Runs `format.sh` and `task-summary.sh` when a teammate completes a task. Quality gates are **not** run as hooks — they are handled by a dedicated Quality Gate agent spawned between task groups.

**Checkpoint display:** "Agent teams — format + log on task completion (quality gates run via dedicated agent)"

---

## Existing Pre-Commit Hooks

When analysis detects `has_husky = true` or `has_lefthook = true`:

1. **Note at checkpoint:** "This project already uses [Husky/Lefthook] for pre-commit hooks. Claude Code hooks run separately and do not conflict — they trigger on Claude-specific events (Stop, PostToolUse), not git hooks."
2. **No action needed** — Claude Code hooks and git pre-commit hooks operate independently.
3. If the project's pre-commit hooks run the same lint/test commands, mention that the quality gate may run them a second time, which is safe but adds latency.

---

## Monorepo Considerations

When `is_monorepo = true`:

1. Hook scripts use `$CLAUDE_PROJECT_DIR` which points to the repo root.
2. Lint and test commands should scope to changed files, not the entire monorepo.
3. If the monorepo uses Turborepo, lint/test may need `--filter` flags — note this at the checkpoint for the developer to confirm.

**Checkpoint display:** "Monorepo detected — hook commands will run from the repo root. Confirm that `[lint_cmd]` and `[test_cmd]` scope correctly."

---

## Checkpoint Summary Format

Present hook recommendations at the human review checkpoint as:

```
### Hooks to Install
- guard.sh — blocks destructive commands
- format.sh — auto-formats with [formatter] on file write
- stop-quality-gate.sh — runs [lint_cmd] + [test_cmd] before completion
- task-summary.sh — session logging
- save-context.sh — WIP snapshot before compaction
- session-start.sh — git state display
[if agent_teams]
- TaskCompleted hook — format + task-summary (quality gates via dedicated agent)
[if has_husky or has_lefthook]
Note: [Husky/Lefthook] pre-commit hooks detected — Claude hooks operate independently.
```
