---
name: review-maintainability
description: Review maintainability risks in HEAD, uncommitted changes, or the current branch against develop, falling back to main or master when develop does not exist. Use when the user asks for a maintainability review, Review Maintainability HEAD, review including uncommitted changes, review against develop/main/master, or focused review of concurrency and thread safety, race conditions, deadlocks, unbounded concurrency, logic bugs, null handling, edge cases, type errors, memory leaks, connection leaks, resource leaks, or unbounded growth in changed code.
---

# Review Maintainability

## Goal

Review only the changes introduced by the current branch against the best available base branch. Prioritize defects that can cause incorrect behavior, unsafe concurrent execution, or resource growth/leaks. Report findings first, in Spanish, with precise file and line references.

## Review Scope

If the user has not already chosen the scope, ask in Spanish before reviewing:

> Seleccioná un preset de review
> 1. Review contra develop (PR Style)
> 2. Review contra main/master (PR Style)
> 3. Review cambios no commiteados
> 4. Review con instrucciones personalizadas

Ask the user to answer only with `1`, `2`, `3`, or `4`. Interpret `1` as **HEAD against develop including uncommitted changes**, `2` as **HEAD against main/master including uncommitted changes**, and `3` as **Uncommitted only**. If the user answers `4`, ask for custom review instructions before selecting files or reading diffs.

For options `1` and `2`, run `git fetch --prune origin` once before resolving the base branch. If fetch fails, warn that remote refs may be stale and continue with local refs. Option `3` does not need a fetch.

Use these scopes:

- **Uncommitted only**: inspect staged, unstaged, and untracked files relative to `HEAD`.
- **HEAD against develop including uncommitted changes**: inspect commits from the merge base with `develop` to `HEAD`, then include staged, unstaged, and untracked files.
- **HEAD against main/master including uncommitted changes**: inspect commits from the merge base with `main` or `master` to `HEAD`, then include staged, unstaged, and untracked files.
- **Custom review instructions**: ask the user for the exact scope and review focus, then apply the closest matching scope above.

Useful commands:

```bash
git fetch --prune origin
git status --short
git diff --cached --name-status
git diff --name-status
git ls-files --others --exclude-standard
git diff --cached
git diff
```

## Base Selection

Prefer remote tracking branches when available because they reflect the shared base more reliably:

- For option `1`, use `origin/develop` if it exists; otherwise use local `develop`.
- For option `2`, use `origin/main` if it exists; otherwise use `origin/master`, then local `main`, then local `master`.
- For option `3`, do not select a base branch; review staged, unstaged, and untracked files relative to `HEAD`.
- For option `4`, ask for custom instructions first, then select the requested base or file scope.

Use `git merge-base HEAD <base>` and review from that merge base to `HEAD`. When the selected scope includes uncommitted changes, inspect staged, unstaged, and untracked files too and say explicitly that the review includes uncommitted changes.

Useful commands:

```bash
git fetch --prune origin
git branch --list develop main master
git branch -r --list origin/develop origin/main origin/master
git merge-base HEAD <base>
git diff --name-status <merge-base>...HEAD
git diff --stat <merge-base>...HEAD
git diff <merge-base>...HEAD -- <path>
git diff --check <merge-base>...HEAD
```

## Review Workflow

1. Identify the base branch and merge base before reading code.
2. List changed files and classify them by runtime responsibility: UI, API route, service, persistence, background job, shared utility, test, config, or documentation.
3. Read the diff first, then open the surrounding implementation for any changed code that depends on invariants outside the diff.
4. Trace changed control flow across module boundaries when a changed function calls or is called by another changed function.
5. Prefer concrete failures over style comments. Do not report broad maintainability opinions unless they create a plausible defect in one of the focus areas.
6. Validate likely findings against code context before reporting. If a risk depends on an assumption, state the assumption clearly or omit the finding.

## Focus Areas

### Concurrency And Thread Safety

Look for:

- Race conditions from async operations resolving out of order.
- Missing cancellation, stale writes, or state updates after teardown.
- Shared mutable state used across requests, sessions, jobs, or tests.
- Deadlocks, lock-order inversions, missing unlocks, or blocking waits inside async/event-loop code.
- Unbounded concurrency from `Promise.all`, loops that start async work without limits, worker pools without caps, queue consumers without backpressure, or retries without bounds.
- Timer, listener, subscription, stream, or observer lifecycles that can overlap unexpectedly.

### Incorrect Behavior Bugs

Look for:

- Logic errors, inverted conditions, unreachable branches, and off-by-one mistakes.
- Null, undefined, empty, missing, or malformed input paths.
- Edge cases around pagination, sorting, filtering, retries, dates, time zones, locale, numeric conversion, and partial API responses.
- Type mismatches, unsafe casts, shape drift between API/service/UI layers, and assumptions not enforced by validation.
- Error handling that swallows failures, reports success after partial failure, retries the wrong operation, or returns inconsistent state.

### Leaks And Resource Management

Look for:

- Memory leaks from retained closures, caches, maps, arrays, global registries, event listeners, or subscriptions.
- Connection, file, stream, transaction, lock, browser, worker, or interval resources not closed on success and failure paths.
- Unbounded growth in caches, queues, logs, telemetry buffers, retry state, polling, or accumulated DOM/application state.
- Missing cleanup in tests that can leak timers, listeners, mocks, servers, or global state into later tests.

## Reporting

Return findings first, ordered by severity. Use Spanish for all review findings and visible explanation.

For each finding include:

- Severity: `P0`, `P1`, `P2`, or `P3`.
- A concise title.
- File and line reference.
- The concrete failure mode.
- Why the changed code introduced or exposed the issue.
- A brief remediation direction.

When the environment supports inline review comments, emit one `::code-comment{...}` directive per finding with a tight line range and Spanish body. Keep the final summary short.

If there are no findings, say that clearly and mention residual risk, such as tests not run or areas not inspectable from the diff.

## Boundaries

- Do not report formatting, naming, architecture, or style issues unless they directly cause one of the focus-area defects.
- Do not review unchanged code as a standalone cleanup target.
- Do not ask for broad rewrites when a focused fix can remove the risk.
- Do not assume tests pass. If relevant tests are known or cheap to run, run them; otherwise state what was not validated.
