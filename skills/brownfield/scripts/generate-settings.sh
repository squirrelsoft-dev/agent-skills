#!/bin/bash
set -e

# generate-settings.sh
# Writes .claude/settings.json and .claude/settings.local.json.
# Outputs JSON status to stdout. Status messages to stderr.
#
# Env vars: PROJECT_DIR, AGENT_TEAMS, PKG_MANAGER

[[ -z "${PROJECT_DIR:-}" ]] && echo "Error: PROJECT_DIR is required" >&2 && exit 1
[[ -z "${PKG_MANAGER:-}" ]] && echo "Error: PKG_MANAGER is required" >&2 && exit 1

echo "Generating settings files..." >&2

mkdir -p "$PROJECT_DIR/.claude"

# --- settings.json ---

if [ "$AGENT_TEAMS" = "true" ]; then
  cat > "$PROJECT_DIR/.claude/settings.json" <<'SETTINGS'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "hooks": {
SETTINGS
else
  cat > "$PROJECT_DIR/.claude/settings.json" <<'SETTINGS'
{
  "hooks": {
SETTINGS
fi

cat >> "$PROJECT_DIR/.claude/settings.json" <<'SETTINGS'
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/guard.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/format.sh\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/stop-quality-gate.sh\""
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/task-summary.sh\""
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/stop-quality-gate.sh\""
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/save-context.sh\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh\""
          }
        ]
      }
SETTINGS

# Add agent teams hooks if enabled
if [ "$AGENT_TEAMS" = "true" ]; then
  cat >> "$PROJECT_DIR/.claude/settings.json" <<'SETTINGS'
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-quality-gate.sh\""
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-quality-gate.sh\""
          }
        ]
      }
    ]
  }
}
SETTINGS
else
  cat >> "$PROJECT_DIR/.claude/settings.json" <<'SETTINGS'
    ]
  }
}
SETTINGS
fi

# --- settings.local.json ---

case "$PKG_MANAGER" in
  npm)
    PERMISSIONS='      "Bash(npm install:*)",
      "Bash(npm run *:*)",
      "Bash(node:*)",
      "Bash(npx tsc:*)"'
    ;;
  pnpm)
    PERMISSIONS='      "Bash(pnpm install:*)",
      "Bash(pnpm run *:*)",
      "Bash(node:*)",
      "Bash(npx tsc:*)"'
    ;;
  yarn)
    PERMISSIONS='      "Bash(yarn install:*)",
      "Bash(yarn run *:*)",
      "Bash(node:*)",
      "Bash(npx tsc:*)"'
    ;;
  bun)
    PERMISSIONS='      "Bash(bun install:*)",
      "Bash(bun run *:*)",
      "Bash(node:*)",
      "Bash(npx tsc:*)"'
    ;;
  pip)
    PERMISSIONS='      "Bash(pip install:*)",
      "Bash(python:*)",
      "Bash(pytest:*)",
      "Bash(ruff:*)"'
    ;;
  poetry)
    PERMISSIONS='      "Bash(poetry install:*)",
      "Bash(poetry run:*)",
      "Bash(python:*)",
      "Bash(pytest:*)",
      "Bash(ruff:*)"'
    ;;
  uv)
    PERMISSIONS='      "Bash(uv sync:*)",
      "Bash(uv run:*)",
      "Bash(python:*)",
      "Bash(pytest:*)",
      "Bash(ruff:*)"'
    ;;
  go)
    PERMISSIONS='      "Bash(go build:*)",
      "Bash(go test:*)",
      "Bash(go run:*)",
      "Bash(go mod:*)",
      "Bash(go vet:*)"'
    ;;
  cargo)
    PERMISSIONS='      "Bash(cargo:*)"'
    ;;
  dotnet)
    PERMISSIONS='      "Bash(dotnet build:*)",
      "Bash(dotnet test:*)",
      "Bash(dotnet run:*)",
      "Bash(dotnet format:*)",
      "Bash(dotnet tool:*)"'
    ;;
  *)
    echo "Warning: unknown PKG_MANAGER '$PKG_MANAGER', using empty permissions" >&2
    PERMISSIONS=""
    ;;
esac

if [ -n "$PERMISSIONS" ]; then
  PERMISSIONS="$PERMISSIONS,"
fi

cat > "$PROJECT_DIR/.claude/settings.local.json" <<LOCALEOF
{
  "permissions": {
    "allow": [
$PERMISSIONS
      "Bash(git add:*)",
      "Bash(git commit:*)"
    ]
  }
}
LOCALEOF

echo "Created .claude/settings.json and .claude/settings.local.json" >&2

cat <<'EOF'
{"status":"ok","files":[".claude/settings.json",".claude/settings.local.json"]}
EOF
