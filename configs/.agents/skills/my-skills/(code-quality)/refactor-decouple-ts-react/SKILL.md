---
name: refactor-decouple-ts-react
description: Decouple JavaScript, TypeScript, and React code by extracting cohesive helpers, constants, types, components, custom hooks, services, and adapters without changing behavior. Use when refactoring large or mixed-responsibility JS/TS/TSX files, splitting React components, moving inline logic out of UI, improving maintainability, reorganizing imports/exports, or preparing safer tests around extracted boundaries.
---

# Refactor Decouple TS React

## Overview

Refactor JS/TS and React code toward explicit boundaries while preserving behavior. Prefer small, purposeful extractions that make the main flow easier to read, test, and change.

Use `refactor-modularity-cohesion-deduplication` as a complementary design guide when the task requires broader modularity, cohesion, or duplication tradeoffs.

## Workflow

1. Inspect the current file, callers, tests, and local folder conventions before moving code. Measure the file length first (e.g. `wc -l`) and record it; the line count drives whether this is a single extraction or a phased refactor (see "Large Files And Phased Refactoring").
2. Name the responsibilities mixed in the current implementation: rendering, state, effects, data fetching, mapping, validation, formatting, constants, types, side effects, or integration.
3. Choose the smallest useful extraction that separates one clear responsibility.
4. Move code to the nearest appropriate boundary, keeping feature-local code feature-local unless it is genuinely shared.
5. Reconnect the caller through explicit inputs and outputs; avoid hidden module state and broad option objects.
6. Update imports, exports, and tests around observable behavior.
7. Verify after every extraction, not only at the end: run typecheck, lint, and the focused tests, and re-measure the file length so the reduction is real and the build still passes.
8. Re-read the main call flow and confirm it is clearer than before.

## Large Files And Phased Refactoring

Long files (roughly 800+ lines, or any file too big to fully restructure in one safe pass) need a phased plan, not one giant edit.

- Measure first and state the number. Treat the line count as a tracked metric: report it before, after each phase, and at the end so progress is visible and verifiable.
- For a large refactor, agree on scope before moving code. Offer phases with rough line-reduction and risk estimates and let the user pick how far to go; do not silently attempt a 1000-line restructure in one shot.
- Extract in dependency order so later phases do not create circular imports:
  1. **Types** — move shared domain shapes to a neutral `*.types.ts` module first. This breaks the coupling that blocks everything else.
  2. **Constants** — stable vocabulary, keys, config-like invariants.
  3. **Pure helpers** — formatting, parsing, sorting, filtering, derivation with no React/JSX/side effects. Functions that return JSX or touch `styles` stay in the component file (or move to a `.tsx`).
  4. **Components, hooks, services** — extract these only after the shared types/helpers they need already live in neutral modules.
- Preserve the external API. When you move an exported type or symbol, re-export it from the original file (`export type { X } from "./new-module"`) so existing importers, pages, and tests keep working without churn.
- One phase per change: extract a cohesive group, verify (typecheck + lint + tests + re-measure), then move to the next. Never batch unrelated extractions because they share a turn.
- It is acceptable to stop after a few safe phases and report remaining ones as clear next steps rather than forcing the whole monolith apart at once.

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

## Validation Checklist

- Run typecheck, lint, and focused tests after every extraction (each phase), not just once at the end; a green check earlier does not survive a later edit that drops an import or symbol.
- Re-measure the file length after each phase and report the before/after numbers so the reduction is concrete.
- Run focused tests for every touched layer and update tests when behavior is exposed through new boundaries.
- Prefer behavior tests over tests that only inspect source text, imports, or implementation strings.
- Confirm extracted modules have clear names, narrow APIs, and one primary reason to change.
- Confirm the caller became easier to scan and did not gain extra plumbing.
- Confirm moved exports are still reachable by external importers (re-exported when needed) and nothing outside the file broke.
- Summarize the design decisions: what moved, why that boundary fits, how behavior was preserved, the line count before/after, and any phases deliberately deferred.
