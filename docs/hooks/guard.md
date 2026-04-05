# guard.sh

**Hook type:** PreToolUse  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)

Runs before every tool use and blocks commands that could cause irreversible damage or expose secrets.

## What it blocks

**Destructive commands:**
- `rm -rf /` and variants
- `DROP TABLE`, `DROP DATABASE`, `DELETE FROM ... WHERE 1=1`
- `git push --force`
- Low-level disk operations (`dd if=`, `mkfs`, `> /dev/sd*`)

**Secret exposure patterns:**
- `curl -d` or `--data` with `_KEY`, `_SECRET`, `_TOKEN`, or `PASSWORD` in the value
- `echo` statements printing environment variables that look like secrets

## What it approves

Everything else. The hook approves by default — it only blocks on explicit pattern matches.

## Decision output

Outputs `{"decision":"approve"}` or `{"decision":"block","reason":"..."}` to stdout. Claude Code reads this before executing the tool.

## Customising

The blocked pattern list is in the `grep -qEi` expression inside `.claude/hooks/guard.sh`. Add patterns to extend coverage for your project's specific risk profile.
