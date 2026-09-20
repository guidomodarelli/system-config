---
name: test-conventions
description: Enforces test naming, structure, coverage expectations, mock placement, reporting blocks (Commentary/Validation/Error), and mandatory test execution before completing any change. Use when creating, updating, or reviewing automated tests.
---

## Quick start

- Confirm the project's test framework and local patterns; default to Jest if unspecified.
- Place tests adjacent to implementation with `.spec` filenames, "should do X when Y" titles, and AAA/GWT structure.
- Cover happy paths, error cases, and significant edge conditions; mock external dependencies via `__mocks__`.
- Do not test source files by reading exact text, styles, SQL strings, SQL fragments, or ORM/query-builder call parameters; assert observable behavior or public contracts instead.
- Provide runnable test code, then include the required Commentary and Validation blocks (and Error when needed).

## Mandatory execution rules

- Before marking any change as done, run the relevant tests and verify they pass.
- When adding, modifying, or removing functionality, add or update the corresponding tests in the same change.
- If tests cannot be executed in the current environment, explicitly state what could not be validated and why.

## Resources

- See [rule.md](references/rule.md) for full conventions and output requirements.
