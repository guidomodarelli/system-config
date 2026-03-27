---
name: mock-first-testing-design
description: Decide whether tests should isolate dependencies with mocks, stubs, spies, fakes, or whether production code should be refactored for better design. Use when creating, updating, or reviewing automated tests and there is a risk of adding test-only branches, exporting internals just for tests, or changing production contracts only to avoid mocks.
---

# Mock First Testing Design

Use this skill to keep tests isolated without contaminating production code with test-only decisions.

## Quick Start

- Identify the dependency that makes the test hard: API, database, filesystem, time, randomness, network, framework wrapper, side-effect, or shared service.
- Prefer a mock, stub, fake, or spy at that boundary before considering production code changes.
- Refactor production code only when the refactor improves design for real usage: clearer responsibilities, lower coupling, explicit dependencies, or smaller units with stable contracts.
- Reject changes whose only purpose is making the test easier.

## Decision Rule

Ask this question before changing production code:

> If this change did not help testing, would it still be a good design change?

- If the answer is `no`, keep production code as-is and solve the test with doubles or better test setup.
- If the answer is `yes`, the refactor is acceptable if it improves the system independently of the test.

## Prefer These Patterns

- Mock external systems and side effects.
- Stub return values when the test only needs controlled inputs.
- Spy on interactions when behavior matters more than output.
- Use fakes for simple in-memory replacements when they keep tests readable.
- Apply dependency injection when it makes dependencies explicit in real design, not only in tests.
- Favor SOLID-oriented refactors that reduce coupling and improve cohesion as a side effect of better design.

## Reject These Patterns

- Do not add `isTest`, `testMode`, or similar branches in production code.
- Do not export internals only to reach them from tests.
- Do not change public contracts only to simplify assertions.
- Do not split or unwrap framework-dependent code only to bypass HOCs, wrappers, or runtime glue in tests.
- Do not rewrite valid production code merely to avoid mocks.
- Do not modify business logic solely to make a failing test pass.

## Acceptable Refactors

Accept a refactor when it:

- makes dependencies explicit;
- separates unrelated responsibilities;
- removes hidden side effects;
- creates smaller, cohesive units with stable behavior; or
- simplifies orchestration without weakening the public contract.

Reject a refactor when it:

- exists only for test reachability;
- introduces test-only seams with no product value; or
- leaks implementation details that should stay private.

## Review Checklist

- Confirm the test isolates the right boundary.
- Confirm production behavior and public contracts remain driven by functional needs.
- Confirm any new seam is a real design improvement, not a testing bypass.
- Confirm the chosen double type matches the test goal: control, observation, or replacement.
- Call out test-only production changes explicitly during review and request a mock-based or design-driven alternative.
