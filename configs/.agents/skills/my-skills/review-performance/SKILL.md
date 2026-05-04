---
name: review-performance
description: Review production-impacting performance issues in changed code. Use when the user asks for a performance review, performance risks, latency or throughput review, or focused detection of N+1 queries, O(n²) or worse algorithms, repeated expensive work, unnecessary allocations, excessive rendering, unbounded loops, missing batching, inefficient I/O, cache misuse, or avoidable production load.
---

# Review Performance

## Goal

Review changed code for performance defects that can affect production latency, throughput, cost, memory, rendering responsiveness, or service reliability. Prioritize issues with a plausible real workload impact over speculative micro-optimizations.

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
