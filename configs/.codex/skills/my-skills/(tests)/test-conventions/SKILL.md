---
name: test-conventions
description: Enforces test naming, structure, coverage expectations, mock placement, and reporting blocks (Commentary/Validation/Error). Use when creating, updating, or reviewing automated tests.
---

## Quick start

- Confirm the project's test framework and local patterns; default to Jest if unspecified.
- Place tests adjacent to implementation with `.spec` filenames, "should do X when Y" titles, and AAA/GWT structure.
- Cover happy paths, error cases, and significant edge conditions; mock external dependencies via `__mocks__`.
- Provide runnable test code, then include the required Commentary and Validation blocks (and Error when needed).

## Resources

- See [rule.md](references/rule.md) for full conventions and output requirements.
