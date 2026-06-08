---
name: fix-tests-intelligently
description: Diagnose failing or flaky tests without blindly modifying assertions or mocks to get green builds. Use when the user is asked to fix tests, address regressions, resolve test-vs-implementation mismatches, or decide whether the correct fix belongs in the test, the implementation, or both.
---

## Quick Start

- Preserve the test's intent before changing anything.
- Inspect the failing test and the implementation together; do not treat the test as disposable.
- Respect the requested edit scope: if the user asked to update tests only, or did not clearly authorize production edits, do not modify implementation files without confirmation.
- Fix the smallest surface that restores the intended behavior.
- Run the relevant tests after the change and verify they pass.

## Workflow

### 1. Analyze the failing test

- Identify the behavior the test is validating.
- Decide whether the expectation matches the real specification, business rule, or public contract.
- Check whether the setup, fixtures, mocks, or test data introduce a false assumption.

### 2. Evaluate the implementation

- Confirm whether the current code matches the intended behavior.
- Look for regressions, missing branches, broken edge-case handling, or invalid output shape.
- Prefer reading adjacent tests and nearby call sites when intent is ambiguous.

### 3. Decide where to fix

- Fix the test when the expectation is outdated, the mock/setup is invalid, or the asserted behavior is not the real requirement.
- Fix the implementation when the test correctly represents the intended behavior and the code violates it.
- Fix both sides only when each is partially wrong, and keep the changes minimal.

### 4. Apply the scope gate before editing

- If the user explicitly says "tests only", "solo tests", or equivalent, modify only test files.
- If the user asks broadly to "fix tests" and the root cause is in implementation code, stop before editing production files. Report the evidence, explain that test-only changes cannot make the suite pass honestly, and ask for confirmation before touching implementation.
- If there are valid test-side issues, apply those first, then rerun the relevant tests and report any remaining implementation parse/runtime failures as blockers.
- Do not mock, skip, or bypass production imports just to satisfy a test-only scope when doing so would hide the real failure.

## Allowed Changes

- Correct assertions that contradict the real contract.
- Replace misleading mocks or fixtures with valid ones.
- Update implementation logic to satisfy correct expectations only when production edits are authorized by the user or clearly within the requested scope.
- Add or adjust focused tests when coverage is missing around the corrected behavior.

## Forbidden Changes

- Remove assertions only to make the suite pass.
- Replace precise checks with weaker matchers without a behavior-based reason.
- Skip, mute, or disable failing tests as a shortcut.
- Change expected values arbitrarily.
- Mock around the bug in a way that hides the real issue.

## Decision Heuristics

- Treat public behavior, business rules, and stable contracts as the source of truth.
- If the failure comes from a renamed field, changed API contract, or updated requirement, prefer updating the test only after verifying that the implementation is intentionally correct.
- If the failure exposes a regression in data handling, control flow, validation, or side effects, prefer fixing the implementation.
- If the intent is unclear, gather evidence first from neighboring tests, docs, types, routes, serializers, or UI expectations before editing.

## Output Requirements

- State whether the root cause was in the test, the implementation, or both.
- Briefly explain why that is the correct place to fix.
- State when the requested scope prevented the root-cause fix, including the specific production files or modules still blocking the suite.
- Apply minimal, targeted changes.
- Keep tests and implementation aligned with the same intended behavior.

## Review Standard

- Do not stop at "tests are green."
- Verify that the final assertions still prove something meaningful.
- Prefer strong, behavior-oriented validations over broad or incidental checks.
