#!/usr/bin/env bats
load '../helpers/setup'
load '../helpers/assertions'

setup() { common_setup; }
teardown() { common_teardown; }

@test "detect-tools: exits with code 0" {
  run "$SCRIPTS_DIR/detect-tools.sh"
  [ "$status" -eq 0 ]
}

@test "detect-tools: outputs valid JSON" {
  run "$SCRIPTS_DIR/detect-tools.sh"
  [ "$status" -eq 0 ]
  local json
  json=$(_extract_json)
  echo "$json" | jq . > /dev/null 2>&1
}

@test "detect-tools: has all 4 keys" {
  run "$SCRIPTS_DIR/detect-tools.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.gitleaks' "$(echo "$(_extract_json)" | jq -r '.gitleaks')"
  assert_json_stdout_field '.semgrep' "$(echo "$(_extract_json)" | jq -r '.semgrep')"
  assert_json_stdout_field '.gh_cli' "$(echo "$(_extract_json)" | jq -r '.gh_cli')"
  assert_json_stdout_field '.trivy' "$(echo "$(_extract_json)" | jq -r '.trivy')"
}

@test "detect-tools: each value is yes or no" {
  run "$SCRIPTS_DIR/detect-tools.sh"
  [ "$status" -eq 0 ]
  local json
  json=$(_extract_json)
  for key in gitleaks semgrep gh_cli trivy; do
    local val
    val=$(echo "$json" | jq -r ".$key")
    [[ "$val" = "yes" || "$val" = "no" ]]
  done
}

@test "detect-tools: gh_cli is yes when gh is installed" {
  if ! command -v gh &>/dev/null; then
    skip "gh not installed"
  fi
  run "$SCRIPTS_DIR/detect-tools.sh"
  [ "$status" -eq 0 ]
  assert_json_stdout_field '.gh_cli' 'yes'
}
