#!/bin/bash
set -e
# generate-hooks.sh
# Writes .claude/hooks/ scripts tailored to detected tools.
#
# Env vars:
#   STACK         required (typescript-node|react|nextjs|python|go)
#   PKG_MANAGER   required (npm|pnpm|yarn|bun|pip|poetry|uv|go)
#   FORMATTER     required (prettier|biome|ruff|gofmt|rustfmt)
#   TEST_RUNNER   optional (vitest|jest|mocha|pytest|go-test)
#   TYPECHECKER   optional, python only (ty|pyright|mypy)

echo "Generating hook scripts..." >&2

mkdir -p .claude/hooks

STACK="${STACK:-unknown}"
PKG_MANAGER="${PKG_MANAGER:-npm}"
FORMATTER="${FORMATTER:-prettier}"
TEST_RUNNER="${TEST_RUNNER:-none}"
TYPECHECKER="${TYPECHECKER:-pyright}"
AGENT_TEAMS="${AGENT_TEAMS:-false}"

# --- guard.sh ---
cat > .claude/hooks/guard.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && echo '{"decision":"approve"}' && exit 0
if echo "$CMD" | grep -qEi '(rm -rf /|DROP TABLE|DROP DATABASE|DELETE FROM .* WHERE 1=1|push\s+.*--force|> /dev/sd|mkfs|dd if=)'; then
  echo '{"decision":"block","reason":"Blocked: destructive command detected."}'
  exit 0
fi
if echo "$CMD" | grep -qEi '(curl.*(-d|--data).*(_KEY|_SECRET|_TOKEN|PASSWORD)|echo.*(_KEY|_SECRET|_TOKEN))'; then
  echo '{"decision":"block","reason":"Blocked: potential secret exposure. Use environment variables."}'
  exit 0
fi
echo '{"decision":"approve"}'
HOOK

# --- format.sh (formatter-specific) ---
cat > .claude/hooks/format.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0
HOOK

case "$FORMATTER" in
  biome)   echo 'npx @biomejs/biome format --write "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  ruff)    echo 'ruff format "$FILE" 2>/dev/null || black "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  gofmt)   echo 'gofmt -w "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  rustfmt) echo 'rustfmt "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
  *)       echo 'npx prettier --write "$FILE" 2>/dev/null || true' >> .claude/hooks/format.sh ;;
esac

# --- stop-quality-gate.sh (scoped, stack-aware) ---
#
# Scoped quality gate. Every tool runs against the set of files changed on the
# current branch (uncommitted + untracked + committed vs merge base). Nothing
# runs against the whole repo — keeps the hook fast on large projects.
#
# NOTE: this template is intentionally duplicated with
# skills/greenfield/scripts/generate-hooks.sh. Skills are distributed
# standalone via `npx skills add`, so each must be self-contained. Keep the
# two in sync when making changes.

GATE=".claude/hooks/stop-quality-gate.sh"

{
  echo '#!/usr/bin/env bash'
  echo '# Scoped quality gate. See skills/brownfield/scripts/generate-hooks.sh.'
  echo 'set -uo pipefail'
  echo 'trap '\''rc=$?; [[ $rc -ne 0 ]] && echo "stop-quality-gate exited with $rc at line $LINENO" >>/tmp/claude-stop-hook.log'\'' EXIT'
  printf 'PM=%q\n' "$PKG_MANAGER"
  printf 'STACK=%q\n' "$STACK"
  printf 'TEST_RUNNER=%q\n' "$TEST_RUNNER"
  printf 'TYPECHECKER=%q\n' "$TYPECHECKER"
} > "$GATE"

# Shared header: bypasses + CHANGED[]/WORKING[] builders + early exit.
cat >> "$GATE" <<'HOOKEOF'

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && echo '{"decision":"approve"}' && exit 0
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "main"')
[[ "$AGENT_TYPE" == "hook-agent" ]] && echo '{"decision":"approve"}' && exit 0

CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || { echo '{"decision":"approve"}'; exit 0; }

[[ -f "$CLAUDE_PROJECT_DIR/.claude/.workflow-running" ]] && { echo '{"decision":"approve"}'; exit 0; }

UNCOMMITTED=$(git diff --name-only HEAD 2>/dev/null || true)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null || true)
MERGE_BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || true)
if [[ -n "$MERGE_BASE" ]]; then
  COMMITTED=$(git diff --name-only "$MERGE_BASE"...HEAD 2>/dev/null || true)
else
  COMMITTED=""
fi

EXCLUDE='(^|/)(node_modules|dist|\.next|\.turbo|coverage|__pycache__|\.venv|venv|vendor|target|build)/'

CHANGED=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ "$f" =~ $EXCLUDE ]] && continue
  [[ ! -f "$f" ]] && continue
  CHANGED+=("$f")
done < <(printf '%s\n%s\n%s\n' "$UNCOMMITTED" "$UNTRACKED" "$COMMITTED" | awk 'NF && !seen[$0]++')

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  echo '{"decision":"approve"}'
  exit 0
fi

WORKING=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ "$f" =~ $EXCLUDE ]] && continue
  [[ ! -f "$f" ]] && continue
  WORKING+=("$f")
done < <(printf '%s\n%s\n' "$UNCOMMITTED" "$UNTRACKED" | awk 'NF && !seen[$0]++')

ERRORS=""

if command -v gitleaks &>/dev/null; then
  LEAK_OUT=""
  for f in "${CHANGED[@]}"; do
    if ! out=$(gitleaks detect --no-git --source="$f" --no-banner 2>&1); then
      LEAK_OUT+="$out"$'\n'
    fi
  done
  if [[ -n "$LEAK_OUT" ]]; then
    ERRORS+=$'\n## Secrets Detected (gitleaks)\n```\n'"$LEAK_OUT"$'\n```\n'
  fi
fi

if command -v semgrep &>/dev/null; then
  if ! output=$(semgrep --config=auto --quiet --error "${CHANGED[@]}" 2>&1); then
    ERRORS+=$'\n## Security Issues (semgrep)\n```\n'"$output"$'\n```\n'
  fi
fi

HOOKEOF

# --- Stack-specific body ---

case "$STACK" in
  typescript-node|react|nextjs)
    cat >> "$GATE" <<'HOOKEOF'
JS_TS=()
for f in "${CHANGED[@]}"; do
  if [[ "$f" =~ \.(js|jsx|mjs|cjs|ts|tsx|mts|cts)$ ]]; then
    JS_TS+=("$f")
  fi
done
WORKING_JS_TS=()
for f in "${WORKING[@]}"; do
  if [[ "$f" =~ \.(js|jsx|mjs|cjs|ts|tsx|mts|cts)$ ]]; then
    WORKING_JS_TS+=("$f")
  fi
done

IS_MONOREPO=0
[[ -f "turbo.json" || -f "turbo.jsonc" ]] && IS_MONOREPO=1
CHANGED_PKG_DIRS=""
if [[ "$IS_MONOREPO" == "1" && ${#CHANGED[@]} -gt 0 ]]; then
  CHANGED_PKG_DIRS=$(printf '%s\n' "${CHANGED[@]}" | awk -F/ '/^(apps|packages)\// {print $1"/"$2}' | sort -u)
fi

if [[ ${#JS_TS[@]} -gt 0 ]] && command -v "$PM" &>/dev/null; then
  if ! output=$("$PM" exec oxlint "${JS_TS[@]}" 2>&1); then
    ERRORS+=$'\n## Lint Failed (oxlint)\n```\n'"$output"$'\n```\n'
  fi
fi

if [[ ${#WORKING_JS_TS[@]} -gt 0 ]] && command -v "$PM" &>/dev/null; then
  if ! output=$("$PM" exec oxfmt --check "${WORKING_JS_TS[@]}" 2>&1); then
    ERRORS+=$'\n## Format Check Failed (oxfmt)\n```\n'"$output"$'\n\nRun: '"$PM"' exec oxfmt $(git diff --name-only HEAD)\n```\n'
  fi
fi

if [[ ${#JS_TS[@]} -gt 0 ]] && command -v "$PM" &>/dev/null; then
  if [[ "$IS_MONOREPO" == "1" && -n "$CHANGED_PKG_DIRS" ]]; then
    FILTERS=""
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      FILTERS+=" --filter=./$pkg"
    done <<< "$CHANGED_PKG_DIRS"
    if ! output=$("$PM" exec turbo run typecheck $FILTERS 2>&1); then
      ERRORS+=$'\n## Typecheck Failed (turbo)\n```\n'"$output"$'\n```\n'
    fi
  elif [[ -f "tsconfig.json" ]]; then
    if ! output=$("$PM" exec tsc --noEmit 2>&1); then
      ERRORS+=$'\n## Typecheck Failed (tsc)\n```\n'"$output"$'\n```\n'
    fi
  fi
fi

if [[ ${#JS_TS[@]} -gt 0 ]] && command -v "$PM" &>/dev/null; then
  if [[ "$IS_MONOREPO" == "1" ]]; then
    UNIQUE_PKGS=$(printf '%s\n' "${JS_TS[@]}" | awk -F/ '/^(apps|packages)\// {print $1"/"$2}' | sort -u)
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      files=()
      for f in "${JS_TS[@]}"; do
        case "$f" in
          "$pkg"/*) files+=("${f#"$pkg"/}") ;;
        esac
      done
      [[ ${#files[@]} -eq 0 ]] && continue
      if [[ -f "$pkg/vitest.config.ts" || -f "$pkg/vitest.config.js" || -f "$pkg/vitest.config.mts" || -f "$pkg/vitest.config.mjs" ]]; then
        if ! output=$(cd "$pkg" && "$PM" exec vitest related "${files[@]}" --run --passWithNoTests 2>&1); then
          ERRORS+=$'\n## Tests Failed ('"$pkg"$', vitest)\n```\n'"$output"$'\n```\n'
        fi
      elif [[ -f "$pkg/jest.config.ts" || -f "$pkg/jest.config.js" || -f "$pkg/jest.config.mjs" ]]; then
        if ! output=$(cd "$pkg" && "$PM" exec jest --findRelatedTests --passWithNoTests "${files[@]}" 2>&1); then
          ERRORS+=$'\n## Tests Failed ('"$pkg"$', jest)\n```\n'"$output"$'\n```\n'
        fi
      fi
    done <<< "$UNIQUE_PKGS"
  else
    if [[ "$TEST_RUNNER" == "vitest" ]] || [[ -f "vitest.config.ts" || -f "vitest.config.js" || -f "vitest.config.mts" || -f "vitest.config.mjs" ]]; then
      if ! output=$("$PM" exec vitest related "${JS_TS[@]}" --run --passWithNoTests 2>&1); then
        ERRORS+=$'\n## Tests Failed (vitest)\n```\n'"$output"$'\n```\n'
      fi
    elif [[ "$TEST_RUNNER" == "jest" ]] || [[ -f "jest.config.ts" || -f "jest.config.js" || -f "jest.config.mjs" ]]; then
      if ! output=$("$PM" exec jest --findRelatedTests --passWithNoTests "${JS_TS[@]}" 2>&1); then
        ERRORS+=$'\n## Tests Failed (jest)\n```\n'"$output"$'\n```\n'
      fi
    fi
  fi
fi

for f in "${CHANGED[@]}"; do
  if [[ "$f" == "package.json" || "$f" == */package.json ]]; then
    if command -v "$PM" &>/dev/null; then
      case "$PM" in
        npm|pnpm|yarn|bun)
          if ! output=$("$PM" audit --audit-level=high 2>&1); then
            ERRORS+=$'\n## Vulnerable Dependencies ('"$PM"$' audit)\n```\n'"$output"$'\n```\n'
          fi
          ;;
      esac
    fi
    break
  fi
done
HOOKEOF
    ;;

  python)
    cat >> "$GATE" <<'HOOKEOF'
PY=()
for f in "${CHANGED[@]}"; do
  [[ "$f" =~ \.py$ ]] && PY+=("$f")
done
WORKING_PY=()
for f in "${WORKING[@]}"; do
  [[ "$f" =~ \.py$ ]] && WORKING_PY+=("$f")
done

if [[ ${#PY[@]} -gt 0 ]] && command -v ruff &>/dev/null; then
  if ! output=$(ruff check "${PY[@]}" 2>&1); then
    ERRORS+=$'\n## Lint Failed (ruff)\n```\n'"$output"$'\n```\n'
  fi
fi

if [[ ${#WORKING_PY[@]} -gt 0 ]] && command -v ruff &>/dev/null; then
  if ! output=$(ruff format --check "${WORKING_PY[@]}" 2>&1); then
    ERRORS+=$'\n## Format Check Failed (ruff format)\n```\n'"$output"$'\n\nRun: ruff format $(git diff --name-only HEAD)\n```\n'
  fi
fi

if [[ ${#PY[@]} -gt 0 ]]; then
  TYPECHECK_PATHS=()
  while IFS= read -r d; do
    [[ -n "$d" ]] && TYPECHECK_PATHS+=("$d")
  done < <(printf '%s\n' "${PY[@]}" | while IFS= read -r f; do dirname "$f"; done | awk 'NF && !seen[$0]++')
  case "$TYPECHECKER" in
    ty)
      if command -v ty &>/dev/null; then
        if ! output=$(ty check "${TYPECHECK_PATHS[@]}" 2>&1); then
          ERRORS+=$'\n## Typecheck Failed (ty)\n```\n'"$output"$'\n```\n'
        fi
      fi
      ;;
    pyright)
      if command -v pyright &>/dev/null; then
        if ! output=$(pyright "${TYPECHECK_PATHS[@]}" 2>&1); then
          ERRORS+=$'\n## Typecheck Failed (pyright)\n```\n'"$output"$'\n```\n'
        fi
      fi
      ;;
    mypy)
      if command -v mypy &>/dev/null; then
        if ! output=$(mypy "${TYPECHECK_PATHS[@]}" 2>&1); then
          ERRORS+=$'\n## Typecheck Failed (mypy)\n```\n'"$output"$'\n```\n'
        fi
      fi
      ;;
  esac
fi

if [[ ${#PY[@]} -gt 0 ]] && command -v pytest &>/dev/null; then
  if pytest --picked --help &>/dev/null; then
    if ! output=$(pytest --picked --mode=branch 2>&1); then
      ERRORS+=$'\n## Tests Failed (pytest --picked)\n```\n'"$output"$'\n```\n'
    fi
  else
    echo "pytest-picked not installed — skipping related-tests run" >&2
  fi
fi

for f in "${CHANGED[@]}"; do
  if [[ "$f" == "pyproject.toml" || "$f" == requirements*.txt ]]; then
    if command -v pip-audit &>/dev/null; then
      if ! output=$(pip-audit 2>&1); then
        ERRORS+=$'\n## Vulnerable Dependencies (pip-audit)\n```\n'"$output"$'\n```\n'
      fi
    fi
    break
  fi
done
HOOKEOF
    ;;

  go)
    cat >> "$GATE" <<'HOOKEOF'
GO=()
for f in "${CHANGED[@]}"; do
  [[ "$f" =~ \.go$ ]] && GO+=("$f")
done
WORKING_GO=()
for f in "${WORKING[@]}"; do
  [[ "$f" =~ \.go$ ]] && WORKING_GO+=("$f")
done

CHANGED_PKGS=()
if [[ ${#GO[@]} -gt 0 ]]; then
  while IFS= read -r d; do
    [[ -n "$d" ]] && CHANGED_PKGS+=("./$d")
  done < <(printf '%s\n' "${GO[@]}" | while IFS= read -r f; do dirname "$f"; done | awk 'NF && !seen[$0]++')
fi

if [[ ${#WORKING_GO[@]} -gt 0 ]] && command -v gofmt &>/dev/null; then
  if output=$(gofmt -l "${WORKING_GO[@]}" 2>&1) && [[ -n "$output" ]]; then
    ERRORS+=$'\n## Format Check Failed (gofmt)\n```\nUnformatted:\n'"$output"$'\n\nRun: gofmt -w $(git diff --name-only HEAD | grep \\.go$)\n```\n'
  fi
fi

if [[ ${#CHANGED_PKGS[@]} -gt 0 ]] && command -v golangci-lint &>/dev/null; then
  if ! output=$(golangci-lint run "${CHANGED_PKGS[@]}" 2>&1); then
    ERRORS+=$'\n## Lint Failed (golangci-lint)\n```\n'"$output"$'\n```\n'
  fi
fi

if [[ ${#CHANGED_PKGS[@]} -gt 0 ]] && command -v go &>/dev/null; then
  if ! output=$(go vet "${CHANGED_PKGS[@]}" 2>&1); then
    ERRORS+=$'\n## Vet Failed (go vet)\n```\n'"$output"$'\n```\n'
  fi
fi

if [[ ${#CHANGED_PKGS[@]} -gt 0 ]] && command -v go &>/dev/null; then
  if ! output=$(go test "${CHANGED_PKGS[@]}" 2>&1); then
    ERRORS+=$'\n## Tests Failed (go test)\n```\n'"$output"$'\n```\n'
  fi
fi

for f in "${CHANGED[@]}"; do
  if [[ "$f" == "go.mod" || "$f" == "go.sum" ]]; then
    if command -v govulncheck &>/dev/null; then
      if ! output=$(govulncheck ./... 2>&1); then
        ERRORS+=$'\n## Vulnerable Dependencies (govulncheck)\n```\n'"$output"$'\n```\n'
      fi
    fi
    break
  fi
done
HOOKEOF
    ;;

  *)
    echo "Warning: unknown STACK '$STACK', emitting stub stack body" >&2
    cat >> "$GATE" <<'HOOKEOF'
# Unknown stack — no language-specific checks. Security blocks above still run.
HOOKEOF
    ;;
esac

# Shared footer: ERRORS check + decision.
cat >> "$GATE" <<'HOOKEOF'

if [[ -n "$ERRORS" ]]; then
  REASON=$(printf '%s' "$ERRORS" | jq -Rs .)
  printf '{"decision":"block","reason":%s}\n' "$REASON"
  exit 0
fi

echo '{"decision":"approve"}'
exit 0
HOOKEOF

# --- task-summary.sh ---
cat > .claude/hooks/task-summary.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
{
  echo "# Session — $TIMESTAMP | Branch: $BRANCH"
  echo ""
  git diff --stat HEAD 2>/dev/null || git status --short
  echo ""
  git log --oneline -5 2>/dev/null
} > "$CLAUDE_PROJECT_DIR/.claude/logs/session-$TIMESTAMP.md" 2>/dev/null
exit 0
HOOK

# --- save-context.sh ---
cat > .claude/hooks/save-context.sh <<'HOOK'
#!/usr/bin/env bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/scratch"
SCRATCH="$CLAUDE_PROJECT_DIR/.claude/scratch/wip-$(date +%Y%m%d-%H%M%S).md"
INPUT=$(cat)
CUSTOM=$(echo "$INPUT" | jq -r '.custom_instructions // empty')
{ echo "# WIP — $(date)"; echo "$CUSTOM"; echo ""; git status --short 2>/dev/null; } > "$SCRATCH"
echo "Context saved to $SCRATCH" >&2
exit 0
HOOK

# --- session-start.sh ---
cat > .claude/hooks/session-start.sh <<'HOOK'
#!/usr/bin/env bash
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
[[ "$AGENT_TYPE" == "subagent" || "$AGENT_TYPE" == "teammate" ]] && exit 0
echo "## Git State"
cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "(not a git repo)"
echo ""
echo "## Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
echo ""
echo "## Recent Commits"
git log --oneline -5 2>/dev/null || echo "(no commits)"
exit 0
HOOK

chmod +x .claude/hooks/*.sh

echo "Hook scripts written and made executable" >&2
HOOKS="guard.sh format.sh stop-quality-gate.sh task-summary.sh save-context.sh session-start.sh"
echo "{\"status\":\"ok\",\"files\":\"$HOOKS\"}"
