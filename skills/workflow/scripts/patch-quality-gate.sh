#!/bin/bash
set -e
# patch-quality-gate.sh
#
# The scoped quality gate emitted by greenfield/brownfield already runs
# gitleaks (per changed file) and semgrep (on CHANGED[]) in its shared
# security block, so workflow no longer needs to inject those.
#
# This script's only job now is to detect whether the installed hook is the
# new scoped template (marker: "# Scoped quality gate") and report status.
# If the hook is an older pre-rewrite version, it instructs the user to
# re-run greenfield or brownfield to regenerate it. Workflow does not try
# to rewrite the hook in place — that would require re-detecting stack,
# package manager, and test runner, duplicating logic the generators own.
#
# Env vars are accepted but ignored (kept for backward compatibility with
# existing SKILL.md invocations): GITLEAKS, SEMGREP, STACK.

GATE=".claude/hooks/stop-quality-gate.sh"

if [ ! -f "$GATE" ]; then
  echo "stop-quality-gate.sh not found — skipping patch" >&2
  echo '{"status":"skipped","reason":"gate not found"}'
  exit 0
fi

if grep -q "# Scoped quality gate" "$GATE"; then
  echo "stop-quality-gate.sh is already the scoped template — no patch needed" >&2
  echo '{"status":"ok","patched":"none","reason":"already-scoped"}'
  exit 0
fi

# Older unscoped hook detected. Workflow doesn't have enough context to
# regenerate it safely — tell the user to re-run greenfield/brownfield.
cat >&2 <<'MSG'

⚠️  Your .claude/hooks/stop-quality-gate.sh is an older, unscoped version.
    Workflow no longer patches it in place. To upgrade to the scoped,
    stack-aware template that only runs tools against changed files:

      1. Re-run greenfield (`/greenfield`) or brownfield (`/brownfield`).
         Both detect existing configs and offer an "Update" path that
         regenerates hooks without re-asking every interview question.

      2. Then re-run workflow — this script will confirm the new hook.

    The existing hook still works; upgrading is optional but recommended
    for speed on larger codebases.

MSG

echo '{"status":"skipped","patched":"none","reason":"legacy-gate-needs-regeneration"}'
exit 0
