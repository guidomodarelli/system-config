---
name: refactor-modularity-cohesion-deduplication
description: Refactor code to improve module boundaries, raise cohesion, and remove harmful duplication without changing behavior. Use when a file or feature mixes responsibilities, repeats business logic, leaks infrastructure details across layers, has hard-to-follow dependencies, or needs to be reorganized into clearer modules such as services, adapters, utils, constants, hooks, or feature-specific folders.
---

# Refactor Modularity Cohesion Deduplication

## Overview

Refactor toward clear responsibilities and smaller, more cohesive modules. Keep the change behavior-preserving, prefer the smallest useful design improvement, and remove duplication only when the shared abstraction makes the code easier to understand and maintain.

## Refactor Goals

- Separate unrelated responsibilities.
- Increase local cohesion inside each module.
- Remove duplicated logic, not just duplicated text.
- Reduce dependency fan-out and hidden coupling.
- Preserve public behavior unless the task explicitly includes a contract change.

## Workflow

1. Identify the current responsibilities in the touched area. Measure the file length first (e.g. `wc -l`) and record it; the size determines whether this is one extraction or a phased modularization (see "Phased Modularization For Large Files").
2. Group code by change reason, dependency set, and business purpose.
3. Decide the target boundaries before moving code.
4. Extract duplicated behavior into the narrowest shared abstraction that fits.
5. Reconnect modules through explicit inputs, outputs, and names.
6. After each extraction, run typecheck, lint, and focused tests, re-measure the file, and only then move to the next boundary; do not defer all verification to the end.

## Phased Modularization For Large Files

A large file (roughly 800+ lines, or one too big to safely restructure in a single pass) is modularized in phases, with verification between them.

- Measure the line count before starting and treat it as a tracked metric: report it up front, after each phase, and at the end. "The file is shorter" must be backed by an actual number.
- When the modularization is large, agree on scope before moving code. Present phases with rough line-reduction and risk estimates and let the user choose how far to go in one pass.
- Sequence phases by dependency direction so each step compiles on its own and avoids circular imports:
  1. **Shared types** to a neutral `*.types.ts` module first — this unblocks every later extraction.
  2. **Constants and shared vocabulary**.
  3. **Pure helpers** grouped by cohesive responsibility (e.g. currency, sorting, filtering, progress) rather than a single junk-drawer `helpers` file. Keep JSX-returning or style-dependent helpers in component files.
  4. **Components, hooks, and services**, once the types and helpers they depend on already live in neutral modules.
- Preserve public behavior and the external API: re-export moved symbols from the original file so importers, pages, and tests do not have to change.
- Keep each phase to one cohesive group, verify it, then continue. Stopping after a few safe phases and listing the remaining ones as next steps is preferable to one risky mega-edit.

## Detect Bad Boundaries

- Split when one file handles unrelated concerns such as mapping, validation, transport, persistence, presentation, and orchestration at once.
- Split when two parts of the same file would likely change for different reasons.
- Split when functions depend on different infrastructure or data shapes.
- Split when the same helper knowledge is reimplemented in several callers.
- Keep code together when the extracted module would only wrap one caller and add naming noise without clarifying a responsibility.

## Choose The Right Destination

- Use `utils/` for pure helpers with no domain ownership and no side effects.
- Use `services/` for orchestration that coordinates repositories, clients, or external systems.
- Use `adapters/` for translation across boundaries such as API payloads, DTOs, or provider-specific formats.
- Use `constants/` for shared domain vocabulary or stable configuration-like invariants.
- Use feature-local folders when the code is only meaningful inside one feature and would become harder to trace if moved to a generic shared folder.

## Raise Cohesion

- Keep functions in the same module when they operate on the same domain concept, input shape, or lifecycle.
- Prefer modules whose exported names can be described with one short sentence.
- Move incidental formatting, parsing, or fallback logic out of core business flows when it obscures the main intent.
- Narrow each module API to the operations the caller actually needs.
- Pass explicit dependencies instead of reaching into global state when that improves testability and local reasoning.

## Remove Duplication Safely

- Deduplicate repeated behavior, algorithms, mapping rules, and decision logic before deduplicating cosmetic syntax.
- Search for existing helpers before creating a new shared abstraction.
- Extract only the stable common part when call sites are similar but not identical.
- Keep tiny one-off repetitions inline when the shared helper would need vague parameters or conditional branches.
- Prefer a well-named intermediate function over a large generic utility.

## Refactor Patterns

- Extract pure derivation logic from controllers, hooks, routes, or components into a focused helper or mapper.
- Separate transport code from business rules so clients and routes remain thin.
- Replace repeated inline object construction with a named builder only when the shape has domain meaning or multiple call sites.
- Split large modules into `constants`, `types`, `mappers`, `validators`, and `service` files only when each new file has a clear responsibility.
- In UI code, move data loading, state transitions, and presentation apart only if the new structure reduces repeated requests or prop plumbing.

## Avoid Over-Refactoring

- Do not create generic abstractions that erase domain language.
- Do not centralize feature-local logic too early.
- Do not split a file into many micro-modules that must always be read together.
- Do not use inheritance or configuration objects when a plain function extraction is enough.
- Do not change behavior, error semantics, or side-effect timing unless the task requires it.

## Design Checks

- Confirm each resulting module has one primary reason to change.
- Confirm the names explain responsibility better than the previous structure.
- Confirm dependencies point inward toward business meaning instead of sideways across unrelated modules.
- Confirm the extracted shared code reduced duplication without introducing flag arguments or caller-specific branching.

## Validation

- Run typecheck, lint, and the relevant tests after each phase, not only at the end; a later edit can drop an import or symbol that an earlier green check would not catch.
- Re-measure the file length after each phase and report the before/after numbers as evidence of the reduction.
- Run the relevant tests for every touched layer and update tests when module boundaries or imports changed.
- Confirm moved exports remain reachable by external importers (re-exported when needed) and nothing outside the file broke.
- Read the main call flow after the refactor and confirm it is shorter or clearer than before.
- If behavior changed unintentionally, collapse the abstraction or move the boundary closer to the callers.
- End with a brief design note that states what was modularized, what duplication was removed, why the new boundaries are more cohesive, the line count before/after, and any phases deliberately deferred.
