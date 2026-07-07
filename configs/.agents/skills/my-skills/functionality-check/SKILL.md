---
name: functionality-check
description: "Determine whether a specific functionality from a spec, draft, or feature description is already implemented in the current codebase — even if the UI components, UX flow, or code structure differ. Use when receiving a draft/spec/mockup and needing to identify what is already covered vs what genuinely needs to be built. Use when asked 'what's missing?', 'is this implemented?', 'what do I still need to build?', or when comparing a feature spec against an existing codebase."
---

# Functionality Check

Analyze whether functionality described in a spec/draft already exists in the codebase, regardless of UI differences.

## Core Principle

**Functionality ≠ UI ≠ UX**. The same functionality can be delivered through completely different UI components or UX flows. When checking if something is implemented:

- A `SegmentedControl` and a `Dropdown` filter both provide **filtering by status** → same functionality
- A `CheckboxList` with inline chips and a `Filters` modal with multi-select dropdowns both provide **multi-criteria filtering** → same functionality
- A `Card` summary and info shown in a header/selector both provide **contextual information display** → same functionality
- An inline editable list and a modal with form fields both provide **editing an entity's attributes** → same functionality

## Workflow

### 1. Extract functional capabilities from the spec

For each component/page in the spec, list the **functional capabilities** it provides, ignoring presentation:

- What data does it display?
- What actions can the user perform?
- What state does it manage?
- What API calls does it make?
- What business logic does it enforce?

Do NOT list UI components (dropdowns, cards, modals). List behaviors: "filter reps by leader", "assign area/process to a single rep", "bulk-assign multiple reps simultaneously".

### 2. Search the codebase for functional equivalents

For each functional capability, search the codebase for code that fulfills the same purpose:

- Search services/API routes for the same data operations (CRUD, filtering, bulk actions)
- Search components for the same user-facing actions (even if wrapped differently)
- Search state management for the same flows (even if the step sequence differs)

Key search strategies:
- grep for domain terms (entity names, action verbs) not component names
- Check API endpoints — if the backend supports it, the frontend likely has a way to trigger it
- Look at interfaces/types — if a type exists for a payload, the flow likely exists
- Check service methods — if `applyBulk(repIds: Array<string>)` exists, bulk operations are supported somewhere

### 3. Classify each capability

For each functional capability from the spec, assign one status:

| Status | Meaning |
|--------|---------|
| ✅ Implemented | Functionality exists, possibly with different UI/UX |
| ⚠️ Partially implemented | Backend/service exists but no UI triggers it, or UI exists but is incomplete |
| ❌ Not implemented | Neither the logic nor any way to trigger it exists |

### 4. Report only what's genuinely missing

Output ONLY the ❌ and ⚠️ items. For ⚠️ items, specify exactly what's missing (e.g., "backend supports bulk IDs but no UI for multi-select exists").

## Anti-patterns to avoid

- **Literal file matching**: Do NOT compare file paths from spec to repo. `presence/FilterBar.jsx` ≠ "FilterBar doesn't exist". The filtering functionality may live in a `Filters` component from a shared library.
- **Component-name matching**: `CheckboxList` in a spec doesn't mean the repo needs `CheckboxList`. If the repo uses `Table` with a selection column, the functionality is covered.
- **Path-structure matching**: A spec organizing code as `services/reps.js` doesn't mean the repo needs that file. The repo may have `api/services/process-contingency.ts` serving the same data.
- **Declaring "not implemented" for UI differences**: Different visual approach = still implemented. A modal vs a drawer, chips vs dropdowns, inline vs popover — these are presentation choices, not functionality gaps.

## Example analysis

**Spec says**: "SegmentedControl with Todos/Dentro/Fuera to filter by presence status"
**Repo has**: `Filters.Dropdown name="statusPresence" options={[{key: 'IN_OPERATION'}, {key: 'OUT_OF_OPERATION'}]}`
**Verdict**: ✅ Implemented — filtering by presence status exists via dropdown instead of segmented control

**Spec says**: "Select multiple reps with checkboxes → bulk assign area/process"
**Repo has**: `applyBulk({ repIds: Array<string> })` endpoint exists, but UI only calls it with `[singleRepId]`
**Verdict**: ⚠️ Partially — backend supports bulk but UI lacks multi-selection trigger

**Spec says**: "Scan QR → show modal with from/to diff → confirm/skip per rep"
**Repo has**: `ScanSession` that calls `scanApply` directly on scan, no intermediate confirm step
**Verdict**: Depends on intent — if the confirm step is a UX requirement (safety gate), it's ❌. If it's just a presentation choice and direct-apply is acceptable, it's ✅.
