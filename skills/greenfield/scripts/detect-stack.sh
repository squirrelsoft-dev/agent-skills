#!/bin/bash
set -e

# detect-stack.sh
# Detects project stack from files in the current directory.
# Outputs JSON to stdout. Status messages to stderr.

echo "Detecting project stack..." >&2

STACK="unknown"
FRAMEWORK="unknown"
PKG_MANAGER="unknown"
FORMATTER="none"
TEST_RUNNER="none"
LANG="unknown"
HAS_TYPESCRIPT="false"

# --- Node.js detection ---
if [ -f "package.json" ]; then
  LANG="javascript"
  PKG_MANAGER="npm"
  FORMATTER="prettier"

  # Package manager
  [ -f "bun.lockb" ] && PKG_MANAGER="bun"
  [ -f "pnpm-lock.yaml" ] && PKG_MANAGER="pnpm"
  [ -f "yarn.lock" ] && PKG_MANAGER="yarn"

  # TypeScript
  [ -f "tsconfig.json" ] && HAS_TYPESCRIPT="true" && LANG="typescript"

  # Formatter
  if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
    FORMATTER="biome"
  elif ls .prettierrc* prettier.config.* 2>/dev/null | grep -q .; then
    FORMATTER="prettier"
  fi

  # Framework
  if grep -q '"next"' package.json 2>/dev/null; then
    FRAMEWORK="nextjs"
    STACK="nextjs"
  elif grep -q '"react"' package.json 2>/dev/null; then
    FRAMEWORK="react"
    STACK="react"
  elif grep -qE '"express"|"fastify"|"hono"' package.json 2>/dev/null; then
    FRAMEWORK="node-api"
    STACK="typescript-node"
  else
    FRAMEWORK="node"
    STACK="typescript-node"
  fi

  # Test runner (priority: vitest > jest > mocha)
  if grep -q '"vitest"' package.json 2>/dev/null; then TEST_RUNNER="vitest"
  elif grep -q '"jest"' package.json 2>/dev/null; then TEST_RUNNER="jest"
  elif grep -q '"mocha"' package.json 2>/dev/null; then TEST_RUNNER="mocha"
  fi

# --- Python detection ---
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  LANG="python"
  STACK="python"
  PKG_MANAGER="pip"
  FORMATTER="ruff"
  TEST_RUNNER="pytest"

  # Package manager (poetry / uv / pip)
  grep -q "poetry" pyproject.toml 2>/dev/null && PKG_MANAGER="poetry"
  grep -q "\[tool.uv\]" pyproject.toml 2>/dev/null && PKG_MANAGER="uv"

  # Sub-framework
  if grep -qE "fastapi|django|flask" requirements.txt pyproject.toml 2>/dev/null; then
    grep -qi "fastapi" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="fastapi"
    grep -qi "django" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="django"
    grep -qi "flask" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="flask"
  fi

# --- Go detection ---
elif [ -f "go.mod" ]; then
  LANG="go"
  STACK="go"
  PKG_MANAGER="go"
  FORMATTER="gofmt"
  TEST_RUNNER="go-test"
  FRAMEWORK="go"

# --- Rust detection ---
elif [ -f "Cargo.toml" ]; then
  LANG="rust"
  STACK="rust"
  PKG_MANAGER="cargo"
  FORMATTER="rustfmt"
  TEST_RUNNER="cargo-test"
  FRAMEWORK="rust"

# --- .NET detection ---
elif find . -maxdepth 1 -name "*.csproj" 2>/dev/null | grep -q .; then
  LANG="csharp"
  STACK="dotnet"
  PKG_MANAGER="dotnet"
  FORMATTER="dotnet-format"
  TEST_RUNNER="dotnet-test"
  FRAMEWORK="dotnet"
fi

echo "Detected: $STACK ($LANG) with $PKG_MANAGER" >&2

# Output JSON
cat <<EOF
{
  "stack": "$STACK",
  "framework": "$FRAMEWORK",
  "lang": "$LANG",
  "pkg_manager": "$PKG_MANAGER",
  "formatter": "$FORMATTER",
  "test_runner": "$TEST_RUNNER",
  "has_typescript": $HAS_TYPESCRIPT
}
EOF
