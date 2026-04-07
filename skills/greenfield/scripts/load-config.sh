#!/usr/bin/env bash
set -e
# Loads skill interview answers from .claude/skill-config.json
# Env: SKILL_NAME (required)
# Stdout: JSON object of answers (empty object if not found)

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
CONFIG_FILE="${PROJECT_DIR}/.claude/skill-config.json"
SKILL_NAME="${SKILL_NAME:?SKILL_NAME required}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo '{}'
  exit 0
fi

jq -r --arg skill "$SKILL_NAME" '.[$skill].answers // {}' "$CONFIG_FILE" 2>/dev/null || echo '{}'
