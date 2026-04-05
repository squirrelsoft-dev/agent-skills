# /security-scan

**Installed by:** [workflow skill](../skills/workflow.md)  
**Installed to:** `.claude/commands/security-scan.md`

Runs a deep on-demand security scan of the codebase. More thorough than the automatic quality gate check.

## Usage

```
/security-scan
```

## What it does

Runs a comprehensive security review covering:
- Hardcoded secrets and credentials
- Dependency vulnerabilities (`npm audit` / `pip audit` / `cargo audit`)
- OWASP Top 10 patterns (injection, broken auth, XSS, etc.)
- Insecure direct object references
- Missing input validation
- Sensitive data exposure in logs or responses

Produces a prioritised report of findings with file and line references.

## Notes

If gitleaks or semgrep are installed, `/security-scan` invokes them in addition to Claude's own analysis.
