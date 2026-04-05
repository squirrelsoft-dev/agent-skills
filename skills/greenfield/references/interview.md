# Developer Interview Questions

This file is loaded by SKILL.md during Step 3 of the greenfield skill.
It defines the questions to ask the developer before generating any artifacts.

## Presentation Rules

- Present **all questions at once** as a numbered list — do not ask one at a time.
- Wait for the developer to answer all questions before proceeding to Step 4.
- Show the detected stack results (from detect-stack.sh) inline with Q3.
- If any answer is unclear, ask a brief follow-up — but do not re-present the full list.

---

## Questions

### Q1 — Project name
- **Ask:** "What is the project name?"
- **Type:** free text (required)
- **Env var:** `PROJECT_NAME`
- **Notes:** Used in CLAUDE.md header and git commit messages. Use the directory name as a suggested default.

### Q2 — Project description
- **Ask:** "Describe the project in 1–2 sentences."
- **Type:** free text (required)
- **Env var:** `PROJECT_DESCRIPTION`
- **Notes:** Used in CLAUDE.md project overview section.

### Q3 — Confirm detected stack
- **Ask (stack detected):** "I detected **[stack]** ([lang]) with [pkg_manager]. Is that correct? If not, what are you building?"
- **Ask (stack unknown):** "I couldn't detect your stack. What are you building? (e.g. Next.js, React, Node.js API, Python, Go, Rust, .NET)"
- **Type:** confirm or correct (required)
- **Env var:** `STACK` (may override detect-stack.sh output)
- **Notes:** Show the full detection result (stack, framework, lang, pkg_manager, formatter, test_runner). If the developer corrects the stack, update all related values accordingly.

### Q4 — Git setup
- **Ask:** "Git setup preference?"
- **Type:** choice (required)
- **Options:**
  - `init` — Initialize git repo and create first commit
  - `done` — Git is already set up, skip
  - `skip` — Don't touch git at all
- **Env var:** `GIT_SETUP`

### Q5 — Agent teams
- **Ask:** "Enable experimental agent teams? (allows Claude to spawn sub-agents)"
- **Type:** yes / no (required)
- **Env var:** `AGENT_TEAMS` → `true` or `false`
- **Notes:** If yes, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true` is added to settings.json env block.

### Q6 — Commit style
- **Ask:** "Commit style preference?"
- **Type:** choice (required)
- **Options:**
  - `conventional` — Conventional Commits (feat:, fix:, chore:, etc.)
  - `freeform` — Free-form commit messages
- **Env var:** `COMMIT_STYLE`
- **Notes:** Written into CLAUDE.md conventions section.

### Q7 — CI/CD
- **Ask:** "Scaffold GitHub Actions CI/CD workflows?"
- **Type:** yes / no (required)
- **Env var:** `CI_CD` → `yes` or `no`
- **Follow-up (if yes):** "Which workflows? (select all that apply)"
  - `lint` — Run linter on push/PR
  - `test` — Run tests on push/PR
  - `build` — Build verification on push/PR
  - `deploy` — Deploy on push to main
- **Env var (follow-up):** `CI_WORKFLOWS` → comma-separated list (e.g. `lint,test,build`)
- **Notes:** Templates are loaded from `references/ci-templates.md` during Step 7.

---

## Environment Variable Summary

| Env var | Source | Used by |
|---|---|---|
| `PROJECT_NAME` | Q1 | generate-claude-md.sh, generate-settings.sh |
| `PROJECT_DESCRIPTION` | Q2 | generate-claude-md.sh |
| `STACK` | Q3 (confirmed/corrected) | generate-rules.sh, generate-hooks.sh, generate-claude-md.sh |
| `GIT_SETUP` | Q4 | SKILL.md Step 6 |
| `AGENT_TEAMS` | Q5 | generate-settings.sh |
| `COMMIT_STYLE` | Q6 | generate-claude-md.sh |
| `CI_CD` | Q7 | SKILL.md Step 7 |
| `CI_WORKFLOWS` | Q7 follow-up | SKILL.md Step 7 |

Additional env vars derived from stack detection (not asked directly):
`PKG_MANAGER`, `FORMATTER`, `TEST_RUNNER`, `LANG`, `FRAMEWORK`, `HAS_TYPESCRIPT`,
`INSTALL_CMD`, `DEV_CMD`, `BUILD_CMD`, `TEST_CMD`, `LINT_CMD`
