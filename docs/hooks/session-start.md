# session-start.sh

**Hook type:** SessionStart  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)

Runs when a new Claude Code session opens. Prints the current git state so Claude immediately knows what branch you're on and what work is in progress.

## Output (printed to session context)

```
## Git State
M  src/api/routes/users.ts
?? src/utils/newfile.ts

## Branch
feat/user-auth

## Recent Commits
abc1234 feat(auth): add JWT validation
def5678 chore: update deps
```

## Notes

- Skips silently for subagent and teammate sessions (only runs for the main agent)
- Handles non-git directories gracefully
- Always exits 0
