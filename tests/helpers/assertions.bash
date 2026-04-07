#!/usr/bin/env bash
# Custom assertion helpers for bats tests

assert_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Expected file to exist: $path" >&2
    return 1
  fi
}

assert_dir_exists() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "Expected directory to exist: $path" >&2
    return 1
  fi
}

assert_file_executable() {
  local path="$1"
  if [[ ! -x "$path" ]]; then
    echo "Expected file to be executable: $path" >&2
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -qF "$pattern" "$file" 2>/dev/null; then
    echo "Expected '$file' to contain '$pattern'" >&2
    echo "--- Actual content ---" >&2
    cat "$file" >&2
    return 1
  fi
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -qF "$pattern" "$file" 2>/dev/null; then
    echo "Expected '$file' NOT to contain '$pattern'" >&2
    return 1
  fi
}

assert_json_field() {
  local file="$1"
  local jq_expr="$2"
  local expected="$3"
  local actual
  actual="$(jq -r "$jq_expr" "$file" 2>/dev/null)"
  if [[ "$actual" != "$expected" ]]; then
    echo "JSON field '$jq_expr' in '$file': expected '$expected', got '$actual'" >&2
    return 1
  fi
}

# Extract the JSON block from mixed stdout/stderr output (bats captures both).
# Handles both single-line {"status":"ok"} and multi-line pretty-printed JSON.
_extract_json() {
  echo "$output" | sed -n '/^{/,/^}/p'
}

assert_json_stdout_field() {
  local jq_expr="$1"
  local expected="$2"
  local json_block
  json_block="$(_extract_json)"
  if [[ -z "$json_block" ]]; then
    echo "No JSON found in stdout" >&2
    echo "--- Full output ---" >&2
    echo "$output" >&2
    return 1
  fi
  local actual
  actual="$(echo "$json_block" | jq -r "$jq_expr" 2>/dev/null)"
  if [[ "$actual" != "$expected" ]]; then
    echo "JSON stdout field '$jq_expr': expected '$expected', got '$actual'" >&2
    echo "--- JSON block ---" >&2
    echo "$json_block" >&2
    return 1
  fi
}

assert_json_stdout_count() {
  local jq_expr="$1"
  local expected="$2"
  local json_block
  json_block="$(_extract_json)"
  local actual
  actual="$(echo "$json_block" | jq "$jq_expr" 2>/dev/null)"
  if [[ "$actual" != "$expected" ]]; then
    echo "JSON stdout count '$jq_expr': expected '$expected', got '$actual'" >&2
    return 1
  fi
}

assert_file_matches() {
  local file="$1"
  local regex="$2"
  if ! grep -qE "$regex" "$file" 2>/dev/null; then
    echo "Expected '$file' to match regex '$regex'" >&2
    return 1
  fi
}
