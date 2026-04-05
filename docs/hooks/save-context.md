# save-context.sh

**Hook type:** PreCompact  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)

Runs before Claude Code compacts the conversation context. Saves a WIP snapshot so nothing is lost when the context window is trimmed.

## Output

Creates `.claude/scratch/wip-YYYYMMDD-HHMMSS.md` containing:
- Timestamp
- Any custom instructions from the hook input
- Current `git status --short`

## Notes

- Creates `.claude/scratch/` if it doesn't exist
- The scratch directory is gitignored by the greenfield/brownfield skill
- Always exits 0 — never blocks compaction
