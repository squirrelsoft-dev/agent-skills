# Go Stack Reference

Loaded by SKILL.md Step 3 when `STACK` is `go`.

---

## Command Mapping

Go has a single toolchain — no package manager variants:

| Env var | Command |
|---|---|
| `INSTALL_CMD` | `go mod download` |
| `DEV_CMD` | `go run .` |
| `BUILD_CMD` | `go build ./...` |
| `TEST_CMD` | `go test ./...` |
| `LINT_CMD` | `go vet ./...` |

### Conditional Overrides

- If `golangci-lint` is available, prefer `LINT_CMD` = `golangci-lint run`
- If `air` is available, prefer `DEV_CMD` = `air` (hot reload during development)

---

## Framework Variants

Go has no framework variants — `FRAMEWORK` is always `go`.

---

## Directory Structure

```
cmd/                  # Application entry points
  server/
    main.go
internal/             # Private packages (not importable by external modules)
pkg/                  # Public library packages (optional)
go.mod                # Module definition
go.sum                # Dependency checksums
```

For simple projects (single binary):
```
main.go
go.mod
go.sum
```

---

## Conventions

- `gofmt` handles all formatting — no style debates
- Errors are values — check and return them explicitly, do not panic
- Short, lowercase package names (no underscores or camelCase)
- Test files use `*_test.go` suffix in the same package
- `internal/` for packages that must not be imported outside the module
- Prefer stdlib over third-party packages when reasonable
- Use `context.Context` as the first parameter for functions that do I/O

---

## Key Dependencies

- Standard library covers most needs (net/http, encoding/json, database/sql)
- golangci-lint (optional — comprehensive linter aggregator)
- air (optional — hot reload for development)
- testify (optional — assertion helpers for tests)

---

## Stop-Hook Quality Gate

The scoped quality gate emitted by `generate-hooks.sh` runs these tools
**only on the packages containing changed `.go` files** (Go lints, vets,
and tests at package granularity — there's no faster unit in the Go
toolchain):

| Stage | Tool | Scope |
|---|---|---|
| Format check | `gofmt -l` | Working-set `.go` files only |
| Lint | `golangci-lint run ./<pkg>` | Packages of changed files |
| Vet | `go vet ./<pkg>` | Packages of changed files |
| Tests | `go test ./<pkg>` | Packages of changed files |
| Dependency audit | `govulncheck ./...` | Only when `go.mod` or `go.sum` is in the change set |

Missing tools are skipped via `command -v`. `golangci-lint` and
`govulncheck` are optional — install them to enable those stages.
