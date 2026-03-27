## Rule: Generate base cases, edge cases, and data mocks

When asked to generate tests, propose scenarios, or create a test plan, provide base cases, edge
cases, and data mocks ready to use.

### Requirements

- **Identify inputs**: props, state, dependencies, callbacks, permissions, and i18n when applicable.
- **Base cases**: list 3 to 8 cases that cover the main flow (render, key props, user events, state
  changes, async when applicable).
- **Edge cases**: list boundary scenarios relevant to the component or hook, for example:
  - empty list, list with one item, very large list
  - `null` or `undefined` props when they can be missing
  - invalid or incomplete props (missing optional fields)
  - error and loading states
  - long texts or extreme values (0, negatives, maximums)
  - failing dependencies (API, hook, selector)
- **Data mocks**: propose mocks aligned to the real shape of props or responses:
  - minimal valid dataset (required fields only)
  - typical dataset (2 to 3 representative items)
  - edge dataset (empty, missing fields, or error)
- **Suggested variants**: for each edge case, provide at least one variant and the expected
  assertion (empty state, fallback, error UI, disabled, default props, etc.).

### Output format

- `Base cases`: list with the expected outcome or primary assertion.
- `Edge cases`: list with the expected outcome or primary assertion.
- `Mocks`: reusable data blocks.
- `Notes`: assumptions, factories, or helpers used.

### Notes

- If the repo has mock factories or helpers, reuse them.
- If there are optional callbacks, include one case with the callback missing and another
  validating the call with correct arguments.
