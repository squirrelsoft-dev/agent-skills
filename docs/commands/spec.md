# /spec

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/spec.md`  
**Requires:** architect agent, task breakdown from `/breakdown`

Generates detailed implementation specs from the task breakdown produced by `/breakdown`. Specs give implementer agents everything they need to work independently.

## Usage

```
/spec <feature-name>
```

## What it does

Reads the task list from `.claude/tasks/<feature>.md` and produces a spec for each task. Each spec includes: files to create or modify, interfaces and type signatures, test cases to write, and any constraints or gotchas.

## Output

Spec files saved to `.claude/specs/<feature>/`. One spec per task.

## Next step

```
/work <feature-name> --all
```

→ [/work documentation](work.md)
