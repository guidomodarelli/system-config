---
name: extract-hardcoded-values
description: Identify repeated or meaningful hardcoded literals and move them to named constants or configuration objects. Use when refactoring JS/TS/React/Nordic code that contains inline strings, numbers, paths, URLs, feature flags, timeouts, limits, labels, or environment-dependent values and the goal is to improve readability, reuse, or maintainability without over-abstracting trivial literals.
---

# Extract Hardcoded Values

## Overview

Extract hardcoded values only when the literal carries business meaning, is reused, is environment-dependent, or makes the code harder to understand. Keep the refactor minimal, preserve behavior, and prefer the nearest clear abstraction instead of creating a global constant by default.

## Decide What To Extract

- Extract literals with domain meaning such as statuses, role names, route fragments, timeout values, retry limits, pagination defaults, feature flags, currency codes, and site-specific values.
- Extract repeated literals when the repetition is intentional and a shared name clarifies the contract.
- Extract values that may vary by environment, site, brand, deployment, or runtime into configuration.
- Keep trivial literals inline when extraction would add indirection without improving clarity.

## Keep These Inline By Default

- `0`, `1`, `-1`, `true`, and `false` when they have obvious local meaning.
- Empty strings used only to initialize state or provide a harmless fallback.
- Short one-off literals used exactly once in a tiny local scope when the name would be noisier than the value.
- Framework conventions that are clearer inline than behind a constant.

## Choose The Right Destination

- Use a local constant inside the function or component when the value is only relevant there.
- Use a module-level constant when multiple functions in the same file share the value.
- Use a domain constants file when the value is reused across modules and represents shared business vocabulary.
- Use configuration when the value can change per environment, site, brand, segment, or deployment.
- Reuse existing `constants/`, `config/`, `settings/`, `utils/`, or feature-specific folders before creating new structure.

## Apply The Refactor

1. Identify the literal and explain why it is meaningful enough to extract.
2. Search the codebase for the same value before creating a new constant.
3. Place the new constant in the narrowest scope that still avoids duplication.
4. Name the constant after its role, not its raw value.
5. Replace all intended usages consistently without changing runtime behavior.
6. Update imports, tests, mocks, and snapshots that depend on the extracted value.

## Naming Rules

- Prefer descriptive names such as `DEFAULT_PAGE_SIZE`, `REQUEST_TIMEOUT_MS`, `SUPPORTED_SITE_CODES`, or `PROFILE_ROUTE_BASE`.
- Include units in numeric names when relevant, such as `MS`, `SECONDS`, `MINUTES`, `PERCENTAGE`, or `COUNT`.
- Distinguish configuration from invariants. Prefer names like `userManagementConfig.apiBaseUrl` for runtime config and `MAX_VISIBLE_RESULTS` for fixed code constants.
- Do not encode implementation history into the name. Name the current business meaning.

## Prefer Configuration Over Constants When

- The value changes across environments or sites.
- The value represents integration endpoints, bucket names, topic names, app identifiers, or external service limits.
- The value is expected to be tuned without changing business logic.
- The repository already centralizes similar values in runtime configuration or environment variables.

## Avoid Bad Extractions

- Do not create a constant for every literal mechanically.
- Do not move a value farther away than necessary.
- Do not group unrelated literals into a generic `constants.js` dump.
- Do not create config for values that are true compile-time invariants.
- Do not rename existing shared constants unless the refactor explicitly includes that cleanup.

## Example Decisions

- Extract `'active'` into `USER_STATUS_ACTIVE` when it is reused across filters, API mapping, and tests.
- Keep `index > -1` inline when it is a standard local check and no domain meaning is added by naming it.
- Move `'https://service.internal'` to runtime configuration when it differs by environment.
- Extract `3000` into `SEARCH_DEBOUNCE_MS` when it controls a user-facing delay or business rule.

## Validation

- Confirm the resulting code reads more clearly than before and the chosen scope is still the narrowest reasonable one.
- Run the relevant tests after the refactor and update them when the public contract moved from inline literals to shared constants or configuration.
