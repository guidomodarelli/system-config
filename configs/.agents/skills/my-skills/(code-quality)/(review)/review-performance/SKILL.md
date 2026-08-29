---
name: review-performance
description: Review production-impacting performance issues in HEAD, uncommitted changes, or changed code against develop/main/master. Use when the user asks for a performance review, Review Performance HEAD, review including uncommitted changes, performance risks, latency or throughput review, or focused detection of N+1 queries, O(n²) or worse algorithms, repeated expensive work, unnecessary allocations, excessive rendering, unbounded loops, missing batching, inefficient I/O, cache misuse, or avoidable production load.
---

# Review Performance

## Goal

Review changed code for performance defects that can affect production latency, throughput, cost, memory, rendering responsiveness, or service reliability. Prioritize issues with a plausible real workload impact over speculative micro-optimizations.

## Review Scope

If the user has not already chosen the scope, ask in Spanish before reviewing:

> Seleccioná un preset de review
> 1. Review contra develop (PR Style)
> 2. Review contra main/master (PR Style)
> 3. Review cambios no commiteados
> 4. Review con instrucciones personalizadas

Ask the user to answer only with `1`, `2`, `3`, or `4`. Interpret `1` as **HEAD against develop including uncommitted changes**, `2` as **HEAD against main/master including uncommitted changes**, and `3` as **Uncommitted only**. If the user answers `4`, ask for custom review instructions before selecting files or reading diffs.

Always run `git fetch --all --prune` before resolving branches, selecting files, or reading diffs. If fetch fails, stop the review and report the fetch error instead of continuing with stale refs.

Use these scopes:

- **Uncommitted only**: inspect staged, unstaged, and untracked files relative to `HEAD`.
- **HEAD against develop including uncommitted changes**: inspect commits from the merge base with `develop` to `HEAD`, then include staged, unstaged, and untracked files.
- **HEAD against main/master including uncommitted changes**: inspect commits from the merge base with `main` or `master` to `HEAD`, then include staged, unstaged, and untracked files.
- **Custom review instructions**: ask the user for the exact scope and review focus, then apply the closest matching scope above.

For option `1`, prefer `origin/develop`, then local `develop`. For option `2`, prefer `origin/main`, then `origin/master`, then local `main`, then local `master`.

Useful commands:

```bash
git fetch --all --prune
git status --short
git branch -r --list origin/develop origin/main origin/master
git branch --list develop main master
git merge-base HEAD <base>
git diff --name-status <merge-base>...HEAD
git diff --cached --name-status
git diff --name-status
git ls-files --others --exclude-standard
```

## Review Workflow

1. Identify the changed files and the production path they affect: request handling, database access, service calls, background jobs, UI rendering, build-time code, tests, or tooling.
2. Read the diff first, then inspect surrounding code only where needed to understand data size, call frequency, lifecycle, or dependency contracts.
3. Estimate the workload shape: number of users, requests, rows, items, renders, retries, pages, files, or events that can exercise the changed path.
4. Report only risks that scale poorly or introduce repeated expensive work in normal production use.
5. Prefer evidence from code paths, loops, query placement, allocations, and API boundaries. If impact depends on an assumption, state it clearly.

## Focus Areas

### Database And Remote Calls

Look for:

- N+1 queries or remote calls introduced inside loops, mappers, resolvers, render paths, hooks, or per-item processors.
- Missing batching, joins, eager loading, prefetching, pagination, projection, or bulk APIs.
- Query filters, sorts, or aggregations moved from the database/service layer into application memory.
- Repeated fetching of invariant data within a request, render, job, or batch.
- Cache keys that are too broad, too narrow, missing invalidation, or likely to amplify load.

### Algorithmic Complexity

Look for:

- Nested loops over request-sized or dataset-sized collections that create O(n²) or worse behavior.
- Repeated `find`, `filter`, `includes`, `indexOf`, sort, regex, parse, serialize, or deep clone work inside loops.
- Work that can be converted to maps, sets, grouping, single-pass aggregation, early exit, or precomputation.
- Unbounded iteration over user-controlled, API-controlled, or storage-controlled collections.
- Retry, polling, recursion, pagination, or queue loops without clear limits or backoff.

### Allocations And Rendering

Look for:

- Large arrays, objects, strings, buffers, DOM nodes, or intermediate collections allocated on hot paths.
- Deep clones, JSON round-trips, repeated serialization, repeated date/number formatting, or repeated expensive object creation.
- UI changes that trigger excessive renders, unstable props, recreated callbacks in large lists, missing virtualization, or expensive calculations during render.
- Logging, metrics, tracing, or error formatting that eagerly builds heavy payloads in high-volume paths.
- Temporary data structures that grow with workload and are retained longer than needed.

## Severity Guidance

- `P0`: Can take down production, exhaust a shared resource, or make a critical path unusable at expected scale.
- `P1`: Likely causes severe latency, throughput, cost, or memory regression on a common production path.
- `P2`: Plausible performance regression for moderate or large inputs, batch sizes, or list rendering.
- `P3`: Localized inefficiency with limited impact but a clear low-risk fix.

## Reporting

Return findings first, ordered by severity. Use Spanish for visible review output.

For each finding include:

- Severity: `P0`, `P1`, `P2`, or `P3`.
- A concise title.
- File and line reference.
- The workload shape that triggers the issue.
- The concrete performance failure mode.
- Why the changed code introduced or exposed the issue.
- A brief remediation direction, such as batching, indexing by key, limiting input, moving work out of render, or avoiding repeated allocation.

When the environment supports inline review comments, emit one `::code-comment{...}` directive per finding with a tight line range and Spanish body.

If there are no findings, say that clearly and mention residual risk, such as missing profiling data, unknown production cardinality, or tests not run.

## Boundaries

- Do not report style-only concerns or premature micro-optimizations.
- Do not demand caching unless the cache key, lifetime, invalidation, and consistency tradeoff are clear.
- Do not review unchanged code as a standalone cleanup target unless changed code newly makes it hot or reachable.
- Do not assume benchmarks or tests pass. Run relevant cheap validations when available; otherwise state what was not validated.
