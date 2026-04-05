# format.sh

**Hook type:** PostToolUse (file writes)  
**Created by:** [greenfield](../skills/greenfield.md) · [brownfield](../skills/brownfield.md)

Runs automatically after Claude writes a file. Formats the file using your project's detected formatter so you never get unformatted code committed.

## Formatter selection

The formatter is selected at generation time based on stack detection and baked into the hook script. It does not re-detect at runtime.

| Stack / Config | Formatter used |
|---|---|
| `biome.json` or `biome.jsonc` present | `npx @biomejs/biome format --write` |
| `.prettierrc*` or `prettier.config.*` present | `npx prettier --write` |
| Python stack | `ruff format` |
| Go stack | `gofmt -w` |
| Rust stack | `rustfmt` |
| .NET stack | `dotnet format --include` |
| Unknown | no-op (logs warning) |

## Behaviour

- Exits silently if no file path is provided in the hook input
- Exits silently if the file no longer exists
- Formatter failures are suppressed (`|| true`) so a formatting error never blocks Claude

## Customising

To change the formatter, edit the command on the last line of `.claude/hooks/format.sh`.
