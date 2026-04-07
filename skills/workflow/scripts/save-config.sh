#!/usr/bin/env bash
set -e
# Saves skill interview answers to .claude/skill-config.json
# Env: SKILL_NAME (required), CONFIG_JSON (required — JSON object of answers)
# Stdout: JSON status

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
CONFIG_FILE="${PROJECT_DIR}/.claude/skill-config.json"
SKILL_NAME="${SKILL_NAME:?SKILL_NAME required}"
CONFIG_JSON="${CONFIG_JSON:?CONFIG_JSON required}"

mkdir -p "$(dirname "$CONFIG_FILE")"

if [ -f "$CONFIG_FILE" ]; then
  existing=$(cat "$CONFIG_FILE")
else
  existing='{}'
fi

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated=$(echo "$existing" | jq \
  --arg skill "$SKILL_NAME" \
  --arg ts "$timestamp" \
  --argjson answers "$CONFIG_JSON" \
  '.[$skill] = { "timestamp": $ts, "answers": $answers }')

echo "$updated" | jq . > "$CONFIG_FILE"
echo '{"status":"ok","file":"'"$CONFIG_FILE"'"}' >&2
