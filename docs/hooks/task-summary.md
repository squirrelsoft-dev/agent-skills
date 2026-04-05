# task-summary.sh

**Hook type:** Stop  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)

Runs when Claude completes a task. Writes a markdown session log to `.claude/logs/` capturing what changed and what commits were made.

## Output

Creates `.claude/logs/session-YYYYMMDD-HHMMSS.md` containing:
- Timestamp and current branch
- `git diff --stat HEAD` (files changed, insertions, deletions)
- Last 5 commits

## Notes

- Creates `.claude/logs/` if it doesn't exist
- The logs directory is gitignored by the greenfield/brownfield skill
- Failures are silently suppressed — a logging failure never blocks Claude
- Always exits 0, so it never triggers Claude feedback
