#!/bin/bash
set -e
# analyze-tests.sh
# Detects test framework, file locations, and utilities.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing test setup..." >&2

FRAMEWORK="none"
FILE_LOCATION="unknown"
FILE_PATTERN="unknown"
HAS_FACTORIES="false"
HAS_FIXTURES="false"
HAS_MSW="false"
COVERAGE_TOOL="none"

# Framework detection
if [ -f "package.json" ]; then
  grep -q '"vitest"' package.json 2>/dev/null  && FRAMEWORK="vitest"
  grep -q '"jest"' package.json 2>/dev/null    && [ "$FRAMEWORK" = "none" ] && FRAMEWORK="jest"
  grep -q '"mocha"' package.json 2>/dev/null   && [ "$FRAMEWORK" = "none" ] && FRAMEWORK="mocha"
  grep -q '"msw"' package.json 2>/dev/null     && HAS_MSW="true"
  grep -q '"@vitest/coverage' package.json 2>/dev/null && COVERAGE_TOOL="v8"
  grep -q '"istanbul"' package.json 2>/dev/null        && COVERAGE_TOOL="istanbul"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  FRAMEWORK="pytest"
elif [ -f "go.mod" ]; then
  FRAMEWORK="go-test"
elif [ -f "Cargo.toml" ]; then
  FRAMEWORK="cargo-test"
fi

# Test file locations
COLOCATED=$(find src app lib -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" 2>/dev/null | head -5 | wc -l)
SEPARATE=$(find tests test __tests__ -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" 2>/dev/null | head -5 | wc -l)

if [ "$COLOCATED" -gt "$SEPARATE" ]; then
  FILE_LOCATION="co-located"
  FILE_PATTERN="*.test.ts alongside source"
elif [ "$SEPARATE" -gt 0 ]; then
  FILE_LOCATION="separate-directory"
  [ -d "tests" ] && FILE_PATTERN="tests/**/*.test.*"
  [ -d "__tests__" ] && FILE_PATTERN="__tests__/**"
fi

# Factory/fixture detection
find . -name "factory*" -o -name "*factory*" -o -name "factories*" 2>/dev/null | grep -v node_modules | grep -q . && HAS_FACTORIES="true"
find . -name "fixture*" -o -name "fixtures*" 2>/dev/null | grep -v node_modules | grep -q . && HAS_FIXTURES="true"

echo "Test analysis complete" >&2

cat <<EOF
{
  "framework": "$FRAMEWORK",
  "file_location": "$FILE_LOCATION",
  "file_pattern": "$FILE_PATTERN",
  "has_factories": $HAS_FACTORIES,
  "has_fixtures": $HAS_FIXTURES,
  "has_msw": $HAS_MSW,
  "coverage_tool": "$COVERAGE_TOOL"
}
EOF
