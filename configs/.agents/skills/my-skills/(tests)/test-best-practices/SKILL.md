---
name: test-best-practices
description: Standardizes React component and hook tests (Jest/Vitest + Testing Library, project test-utils wrapper, assertions, mocks, and per-locale or per-market variants). Use when new tests, test refactors, or test convention reviews are requested in React projects.
---

## Quick start

- Identify if the request is for component/hook tests or for texts and behavior that vary by locale, market, or tenant.
- For component/hook tests, open `references/tests-by-component.md` plus `references/expectations.md` and `references/before-applying-mocks.md`.
- For per-locale or per-market variants, open `references/tests-by-locale.md` and apply the `describe.each` pattern.

## Resources

- See [tests-by-component.md](references/tests-by-component.md) for the project's test-utils wrapper and provider setup.
- See [expectations.md](references/expectations.md) for assertion rules and examples.
- See [before-applying-mocks.md](references/before-applying-mocks.md) for mock decision workflow and patterns.
- See [tests-by-locale.md](references/tests-by-locale.md) for `describe.each` patterns across locales, markets, or tenants.
