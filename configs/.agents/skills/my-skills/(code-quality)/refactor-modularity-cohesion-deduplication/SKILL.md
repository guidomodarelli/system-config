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

## Shared execution

Read [ejecución compartida](../references/refactor-execution.md) before editing. Apply its phases, metrics, and validation workflow.

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

Apply shared validation per phase. Confirm also that removed duplication shares semantics and that new abstraction introduces no caller-specific flags or branches.
