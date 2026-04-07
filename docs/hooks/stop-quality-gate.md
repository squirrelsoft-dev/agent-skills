# stop-quality-gate.sh

**Hook type:** Stop  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)

Runs when Claude tries to mark a task complete. Executes your project's lint and test commands against changed files. If either fails, Claude receives the error output and must fix it before completing — it cannot bypass this gate.

## How it works

1. Reads `stop_hook_active` from the hook input — exits immediately if true (prevents infinite loops when the hook itself spawns Claude)
2. Reads `agent_type` — exits immediately for `hook-agent` sessions
3. Detects changed files using `git diff HEAD` combined with commits since the branch diverged from main
4. If no files have changed, exits 0 (nothing to check)
5. Runs `$LINT_CMD` — captures output
6. Runs `$TEST_CMD` — captures output
7. If either failed, prints a formatted error report to stderr and exits 2
8. Exit code 2 tells Claude Code to send the error back to Claude as feedback

## Lint and test commands

The `LINT_CMD` and `TEST_CMD` values are baked in from stack detection at generation time:

| Stack | Default LINT_CMD | Default TEST_CMD |
|---|---|---|
| nextjs / react / typescript-node | `npm run lint` / `pnpm run lint` | `npm test -- --passWithNoTests` |
| python | `ruff check .` | `pytest --tb=short -q` |
| go | `go vet ./...` | `go test ./...` |
| rust | `cargo clippy` | `cargo test` |
| dotnet | `dotnet build` | `dotnet test` |

To change them, edit the `LINT_CMD` and `TEST_CMD` lines near the top of `.claude/hooks/stop-quality-gate.sh`.

## The `# Lint` landmark

The `stop-quality-gate.sh` file contains a `# Lint` comment that serves as an insertion point. The workflow skill's `patch-quality-gate.sh` uses this landmark to add gitleaks, semgrep, and npm audit blocks before the lint step. Do not remove this comment if you plan to run `/workflow`.

## Teammate variant

When agent teams are enabled, `teammate-quality-gate.sh` is **not** created. The `TeammateIdle` hook is removed entirely. The `TaskCompleted` hook runs `format.sh` (auto-format changed files) and `task-summary.sh` (write session log) only — it does not run lint or test gates.

Quality gates in teams mode are handled by a dedicated **Quality Gate agent** spawned by the main agent after each group completes. The Quality Gate agent runs all 8 gates (lint, typecheck, build, test, simplify, review, security-review, security-scan) with a fix-loop per gate, absorbing all retry context to keep the main agent's context minimal.
