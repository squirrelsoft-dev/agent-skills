# CI/CD Workflow Templates

This file contains GitHub Actions workflow templates for each supported stack.
It is loaded by SKILL.md during Step 7 when the developer opts into CI/CD scaffolding.

SKILL.md substitutes `$PLACEHOLDER` values with the detected/confirmed stack values
before writing the workflow files to `.github/workflows/`.

**Note:** Node.js/Next.js templates use `$PLACEHOLDER` vars because commands vary by
package manager. Python and Go templates hardcode stack-standard commands since they
are consistent across projects.

---

## Node.js / TypeScript

**Stacks:** `typescript-node`, `react`
**File:** `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: '$PKG_MANAGER'

      - name: Install dependencies
        run: $INSTALL_CMD

      - name: Lint
        run: $LINT_CMD

      - name: Test
        run: $TEST_CMD

      - name: Build
        run: $BUILD_CMD
```

---

## Next.js

**Stacks:** `nextjs`
**File:** `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: '$PKG_MANAGER'

      - name: Install dependencies
        run: $INSTALL_CMD

      - name: Lint
        run: $LINT_CMD

      - name: Test
        run: $TEST_CMD

      - name: Cache Next.js build
        uses: actions/cache@v4
        with:
          path: .next/cache
          key: nextjs-${{ hashFiles('**/package-lock.json', '**/pnpm-lock.yaml', '**/yarn.lock', '**/bun.lockb') }}
          restore-keys: nextjs-

      - name: Build
        run: $BUILD_CMD
        env:
          NEXT_TELEMETRY_DISABLED: 1

  # Uncomment to add deployment:
  # deploy:
  #   needs: ci
  #   if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  #   runs-on: ubuntu-latest
  #   steps:
  #     - uses: actions/checkout@v4
  #     # Add your deployment steps here (Vercel, Netlify, etc.)
```

---

## Python

**Stacks:** `python`
**File:** `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          # Use 'pip' for pip, 'poetry' for poetry. uv does its own caching.
          cache: 'pip'

      - name: Install dependencies
        run: $INSTALL_CMD

      - name: Lint
        run: $LINT_CMD

      - name: Test
        run: $TEST_CMD
```

---

## Go

**Stacks:** `go`
**File:** `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Vet
        run: go vet ./...

      - name: Test
        run: go test ./...

      - name: Build
        run: go build ./...
```

---

## Generic

**Stacks:** `unknown`, `rust`, `dotnet`, or any unsupported stack
**File:** `.github/workflows/ci.yml`

Use this as a starting point and customize for your stack.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # TODO: Add setup step for your language/runtime
      # - uses: actions/setup-XXX@vN
      #   with:
      #     XXX-version: 'X.Y'

      - name: Install dependencies
        run: echo "Add your install command here"

      - name: Lint
        run: echo "Add your lint command here"

      - name: Test
        run: echo "Add your test command here"

      - name: Build
        run: echo "Add your build command here"
```
