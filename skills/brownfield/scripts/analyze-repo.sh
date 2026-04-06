#!/bin/bash
set -e
# analyze-repo.sh
# Detects project stack, framework, package manager, formatter, and commands.
# Output: JSON to stdout. Status: stderr.

echo "Analyzing repository structure..." >&2

STACK="unknown"
FRAMEWORK="unknown"
PKG_MANAGER="unknown"
FORMATTER="none"
LANG="unknown"
HAS_TYPESCRIPT="false"
IS_MONOREPO="false"
LINT_CMD=""
TEST_CMD=""
BUILD_CMD=""
DEV_CMD=""
INSTALL_CMD=""
HAS_HUSKY="false"
HAS_LEFTHOOK="false"

# Monorepo
[ -f "turbo.json" ] && IS_MONOREPO="true"
[ -f "pnpm-workspace.yaml" ] && IS_MONOREPO="true"
[ -f "lerna.json" ] && IS_MONOREPO="true"

# Pre-commit hooks
[ -d ".husky" ] && HAS_HUSKY="true"
{ [ -f ".lefthook.yml" ] || [ -f "lefthook.yml" ]; } && HAS_LEFTHOOK="true"

if [ -f "package.json" ]; then
  LANG="javascript"
  [ -f "bun.lockb" ]      && PKG_MANAGER="bun"
  [ -f "pnpm-lock.yaml" ] && PKG_MANAGER="pnpm"
  [ -f "yarn.lock" ]      && PKG_MANAGER="yarn"
  [ "$PKG_MANAGER" = "unknown" ] && PKG_MANAGER="npm"
  [ -f "tsconfig.json" ] && HAS_TYPESCRIPT="true" && LANG="typescript"

  { [ -f "biome.json" ] || [ -f "biome.jsonc" ]; } && FORMATTER="biome" || true
  ls .prettierrc* prettier.config.* 2>/dev/null | grep -q . && FORMATTER="prettier" || true

  grep -q '"next"' package.json 2>/dev/null    && FRAMEWORK="nextjs"    && STACK="nextjs"
  grep -q '"react"' package.json 2>/dev/null   && FRAMEWORK="react"     && STACK="react"
  grep -qE '"express"|"fastify"|"hono"' package.json 2>/dev/null && FRAMEWORK="node-api" && STACK="typescript-node"
  [ "$STACK" = "unknown" ] && FRAMEWORK="node" && STACK="typescript-node"

  # Extract scripts from package.json
  has_script() { node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts['$1']?0:1)" 2>/dev/null; }
  has_script "lint"  && LINT_CMD="$PKG_MANAGER run lint"
  has_script "test"  && TEST_CMD="$PKG_MANAGER test"
  has_script "build" && BUILD_CMD="$PKG_MANAGER run build"
  has_script "dev"   && DEV_CMD="$PKG_MANAGER run dev"
  INSTALL_CMD="$PKG_MANAGER install"

  # Add passWithNoTests flag for jest/vitest
  grep -qE '"vitest"|"jest"' package.json 2>/dev/null && TEST_CMD="$TEST_CMD -- --passWithNoTests"

elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  LANG="python"; STACK="python"; FORMATTER="ruff"
  PKG_MANAGER="pip"; INSTALL_CMD="pip install -r requirements.txt"
  LINT_CMD="ruff check ."; TEST_CMD="pytest --tb=short -q"
  grep -q "poetry" pyproject.toml 2>/dev/null && PKG_MANAGER="poetry" && INSTALL_CMD="poetry install"
  grep -q "\[tool.uv\]" pyproject.toml 2>/dev/null && PKG_MANAGER="uv" && INSTALL_CMD="uv sync"
  grep -qi "fastapi" requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="fastapi"
  grep -qi "django"  requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="django"
  grep -qi "flask"   requirements.txt pyproject.toml 2>/dev/null && FRAMEWORK="flask"

elif [ -f "go.mod" ]; then
  LANG="go"; STACK="go"; PKG_MANAGER="go"; FRAMEWORK="go"; FORMATTER="gofmt"
  LINT_CMD="go vet ./..."; TEST_CMD="go test ./..."
  BUILD_CMD="go build ./..."; INSTALL_CMD="go mod download"

elif [ -f "Cargo.toml" ]; then
  LANG="rust"; STACK="rust"; PKG_MANAGER="cargo"; FRAMEWORK="rust"; FORMATTER="rustfmt"
  LINT_CMD="cargo clippy"; TEST_CMD="cargo test"
  BUILD_CMD="cargo build --release"; INSTALL_CMD="cargo build"

elif ls *.csproj 2>/dev/null | grep -q .; then
  LANG="csharp"; STACK="dotnet"; PKG_MANAGER="dotnet"; FRAMEWORK="dotnet"
  FORMATTER="dotnet-format"; LINT_CMD="dotnet build"
  TEST_CMD="dotnet test"; BUILD_CMD="dotnet build --configuration Release"
  INSTALL_CMD="dotnet restore"
fi

echo "Detected: $STACK ($LANG) with $PKG_MANAGER" >&2

cat <<EOF
{
  "stack": "$STACK",
  "framework": "$FRAMEWORK",
  "lang": "$LANG",
  "pkg_manager": "$PKG_MANAGER",
  "formatter": "$FORMATTER",
  "has_typescript": $HAS_TYPESCRIPT,
  "is_monorepo": $IS_MONOREPO,
  "has_husky": $HAS_HUSKY,
  "has_lefthook": $HAS_LEFTHOOK,
  "commands": {
    "lint": "$LINT_CMD",
    "test": "$TEST_CMD",
    "build": "$BUILD_CMD",
    "dev": "$DEV_CMD",
    "install": "$INSTALL_CMD"
  }
}
EOF
