---
name: optimistic-action-mutations
description: Apply reusable optimistic mutation patterns for fast, repeatable UI actions that update local state before persistence and then reconcile with the server. Use when implementing or refactoring interactions like like/unlike buttons, pin/unpin buttons, poll votes, option selection, saves, follows, reactions, bookmarks, or any rapid toggle/select action that needs debounce, request coalescing, safe rollback, concurrency protection, and minimal mutation responses in React, Next.js, or similar frontend/backend flows.
---

# Optimistic Action Mutations

## Overview

Use this skill to implement fast user interactions that feel immediate while preserving server truth. The pattern is: capture a stable baseline, apply an optimistic intent, debounce or coalesce repeated input, submit the latest intent, reconcile with the response, and roll back safely on failure.

## Workflow

1. Identify the action shape:
   - Toggle: `likedByViewer`, `isPinned`, `isFollowing`.
   - Selection: poll option ids, selected filters, ranking choices.
   - Counter-backed action: local state includes counts or percentages.
   - Ordered action: local state affects sorting, badges, timestamps, or pinned ordering.

2. Start with the smallest failing test:
   - Assert immediate optimistic UI feedback.
   - Assert rapid repeated input sends the latest meaningful intent only.
   - Assert rollback restores the captured baseline on failure.
   - Assert stale responses do not update a changed route, entity, or context.
   - Assert server responses reconcile counts, timestamps, sort order, and selected state.

3. Model pending intent per entity id:
   - Store `baseline...` fields from the last persisted server state.
   - Store `intended...` fields from the latest user action.
   - Store `isRequestInFlight`.
   - Store `shouldFlushAfterRequest` when input arrives during an active request.
   - Keep timers and pending intents in refs or equivalent non-render state.

4. Apply optimistic state immediately:
   - Toggle booleans directly from current visible state.
   - Update counters with bounded arithmetic such as `Math.max(0, nextCount)`.
   - Recalculate derived values such as percentages from the optimistic total.
   - Re-sort affected lists when the action changes ordering.
   - Preserve accessibility and disabled/loading states for actions that cannot safely repeat.

5. Debounce the flush, not the visual feedback:
   - Clear any existing timer for the same entity id.
   - Schedule a flush using a named delay constant.
   - On flush, skip the request if the intended state equals the baseline.
   - If a request is already in flight, mark `shouldFlushAfterRequest` and return.

6. Reconcile the response:
   - Validate the response shape before applying it.
   - Ignore stale responses when the route, scope, or selected entity changed.
   - If server state matches the latest intent, apply the server result and clear pending intent.
   - If the user changed intent while the request was in flight, promote the response to the new baseline, reapply the optimistic latest intent, and flush again.
   - Use the server response as the source of truth for counters, timestamps, permissions, and status messages.

7. Roll back intentionally:
   - Restore the captured baseline state, not an inferred old value.
   - Clear the pending intent and timer for that entity.
   - Show a safe, specific user-facing error.
   - Use warning feedback for business-limit failures and error feedback for unexpected failures.

## Server Contract

Design the mutation endpoint or server action to return the minimum view model needed to reconcile the affected UI. Do not force a full route refresh when the client can update safely from the mutation result.

For toggle actions, return the persisted boolean, relevant counts, and a stable status. For ordered actions, return timestamps or ordering fields. For selection actions, return the persisted selected ids, option counts, percentages, totals, and viewer state.

Make server writes safe under retries and concurrent requests:
   - Use idempotent inserts/deletes or upserts for toggles.
   - Use transactions around multi-step mutations.
   - Use database constraints for uniqueness.
   - Use advisory locks or equivalent protection for per-user/per-resource replacement flows.
   - Re-read aggregate state after the write and return persisted values.

## Client Checklist

- Keep pending state keyed by the entity id being mutated.
- Capture baseline from persisted state only once per pending intent.
- Treat the latest user intent as authoritative while a request is pending.
- Use named constants for debounce delays, limits, statuses, and copy keys.
- Validate response types before applying state.
- Guard against stale route/context responses.
- Clean up timers and pending intent refs on unmount or scope reset.
- Keep user-facing copy safe and localized according to the repository rules.
- Avoid exposing provider payloads, stack traces, tokens, or internal diagnostics in UI feedback.

## Test Checklist

- Optimistic state appears immediately after the interaction.
- Repeated rapid interactions are coalesced into the latest meaningful intent.
- Returning to the original baseline cancels the unnecessary request.
- A response matching the latest intent clears pending state.
- A response older than the latest intent becomes the new baseline and triggers another flush.
- Network or validation failure restores the captured baseline.
- Business-limit responses show warning feedback and preserve server truth.
- Stale responses from a previous route or scope are ignored.
- Timers are cleared during unmount/reset.
- Server mutation tests cover idempotency, constraints, permission failures, and aggregate re-read behavior.

## Naming Pattern

Prefer explicit names that describe the action and state:

- `PendingLikeIntent`, `PendingPinIntent`, `PendingPollVoteIntent`
- `baselineLikedByViewer`, `baselineLikeCount`, `intendedLikedByViewer`
- `clearLikeDebounceTimer`, `schedulePendingLikeIntentFlush`, `flushPendingLikeIntent`
- `applyMessageLikeState`, `applyMessagePinState`, `updateMessagePoll`
- `getOptimisticPollVote`, `getOptimisticPinnedAt`

Keep these names in English even when surrounding product copy is localized.

## Avoid

- Do not debounce the visual state update.
- Do not use stale visible state as rollback data after multiple clicks.
- Do not overwrite a newer user intent with an older server response.
- Do not use a full page refresh as the default reconciliation strategy.
- Do not mock platform/UI libraries just to test this pattern; test observable behavior at the component or use-case boundary.
- Do not return raw provider or database errors to the UI.
