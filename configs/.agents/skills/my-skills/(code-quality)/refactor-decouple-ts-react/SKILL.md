---
name: refactor-decouple-ts-react
description: Decouple JavaScript, TypeScript, and React code by extracting cohesive helpers, constants, types, components, custom hooks, services, and adapters without changing behavior. Use when refactoring large or mixed-responsibility JS/TS/TSX files, splitting React components, moving inline logic out of UI, improving maintainability, reorganizing imports/exports, or preparing safer tests around extracted boundaries.
---

# Refactor Decouple TS React

## Overview

Refactor JS/TS and React code toward explicit boundaries while preserving behavior. Prefer small, purposeful extractions that make the main flow easier to read, test, and change.

Use `refactor-modularize-code` as a complementary design guide when the task requires broader modularity, cohesion, or duplication tradeoffs.

## Shared execution

Read [ejecución compartida](../references/refactor-execution.md) before editing. Apply its phases, metrics, and validation workflow.

## Extraction Targets

- Use `helpers/` or `utils/` for pure, reusable derivation with no React dependency and no side effects.
- Use `constants/` for stable values with functional meaning, shared vocabulary, thresholds, keys, or configuration-like invariants.
- Use `types/` for shared TypeScript contracts, public props, DTOs, and domain shapes used by more than one module.
- Use `components/` for presentational React UI with clear props and minimal business logic.
- Use `hooks/` for reusable React state, effects, event orchestration, and data-flow composition.
- Use `services/` for business orchestration, API-facing coordination, or non-UI operations with side effects.
- Use `adapters/` for translating external payloads, API responses, SDK shapes, or persistence formats into local domain shapes.

Keep code colocated when the extracted module would have only one vague name, one caller, or more parameters than useful behavior.

## React Guidelines

- Keep rendering components focused on markup, user actions, and composition.
- Extract custom hooks only when they own reusable React lifecycle, state transitions, subscriptions, or async coordination.
- Keep pure mapping and formatting outside hooks when it does not need React.
- Pass stable, descriptive props instead of leaking source payloads through many component layers.
- Preserve loading, error, empty, disabled, and accessibility behavior during extraction.
- Keep user-facing strings and platform-specific patterns aligned with the project conventions.

## TypeScript Guidelines

- Prefer explicit exported types at module boundaries.
- Keep internal helper types unexported unless callers need them.
- Avoid `any`, broad unions, and catch-all records when the original code has a narrower contract.
- Preserve existing runtime validation and error semantics.
- Use descriptive names for extracted functions, parameters, files, and folders.

## Avoid Over-Refactoring

- Do not split code only because a file is long; split when responsibilities or change reasons differ.
- Do not create generic abstractions that hide domain language.
- Do not move feature-specific logic into global shared folders prematurely.
- Do not combine unrelated extractions in the same change unless they are required by the same boundary.
- Do not change behavior, side-effect timing, cache keys, or API contracts unless the user explicitly asks.

## Closeout

Summarize extracted boundary, preserved contracts, principal/feature metrics, and deferred phases.
