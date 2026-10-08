---
name: test-best-practices
description: Standardizes React component tests in MELI (Jest + @/tests/utils, assertions, mocks, i18n per site). Use when new tests, test refactors, or test convention reviews are requested in MELI projects.
---

## Quick start

- Identify if the request is for component/hook tests or for per-site translations.
- For component/hook tests, open `references/tests-by-component.md` plus `references/expectations.md` and `references/before-applying-mocks.md`.
- For per-site translations, open `references/tests-by-site.md` and apply the `describe.each` + `pxConfig` patterns.

## Resources

- See [tests-by-component.md](references/tests-by-component.md) for `@/tests/utils` and i18n setup.
- See [expectations.md](references/expectations.md) for assertion rules and examples.
- See [before-applying-mocks.md](references/before-applying-mocks.md) for mock decision workflow and patterns.
- See [tests-by-site.md](references/tests-by-site.md) for `describe.each` patterns, `pxConfig`, and usage examples.
