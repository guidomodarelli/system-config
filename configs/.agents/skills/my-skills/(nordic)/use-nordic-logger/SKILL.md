---
name: use-nordic-logger
description: Replaces console.* with nordic/logger in MELI/Nordic codebases (api routes, middleware, services, SSR) and follows local LoggerFactory patterns. Use when adding or updating logging, when refactoring console usage, or when fixing lint warnings or errors triggered by the `no-console` rule.
---

# Use Nordic Logger

## Quick start

- Trigger this skill when ESLint or another linter reports a `no-console` warning or error.
- Create a module logger with `LoggerFactory` from `nordic/logger` (one per file).
- Replace `console.*` with `logger.<level>` calls; keep levels consistent (`error` for failures, `info` for expected flows).
- Log specific, actionable messages with safe context (operation, identifiers, request metadata) when relevant.
- Avoid secrets or PII in log payloads; prefer `error.message` or a safe summary over raw objects.
- Log before sending error responses in API or SSR handlers so failures are observable without leaking details to users.
- Leave tooling-only console usage that is explicitly exempted (for example, `eslint-disable no-console`) unless asked to refactor it.

## Examples

- See [nordic-logger-examples.md](references/nordic-logger-examples.md) for in-repo patterns.
