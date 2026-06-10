---
name: kraken-jira-ticket
description: >
  Creates or updates a JIRA ticket (parent + subtasks) in the Kraken / Shipping Groot project
  (SGP1) for work done in fury_kraken-auth-admin-fe. On create: builds ticket and subtasks from
  the git diff. On update: fetches current parent and all subtasks, re-reads the diff, and
  patches only what has drifted (title, description, subtask titles, subtask descriptions),
  creating missing subtasks when needed. Use when the user asks to create, update, or sync
  a JIRA ticket for changes in the kraken-auth-admin-fe repository.
compatibility: Requires Atlassian MCP and meli-claude-memory MCP. Designed for Claude Code.
metadata:
  author: gmodarelli_meli
  version: "1.0"
---

# Kraken JIRA Ticket

Create or update a ticket in the **SGP1 — Shipping Groot** project for work done in
`fury_kraken-auth-admin-fe`.

> **NEVER run `git push` or any git upload command during this skill.**
> Ticket management is independent of repository state.

---

## Step 1 — Project config (fixed) + derive quarter from system date

The project config for kraken-auth-admin-fe is fixed — no need to search memory for it:

| Field | Value |
|---|---|
| `cloudId` | `a55c251b-e222-488f-8975-3ccdf0a0db6f` |
| `projectKey` | `SGP1` |
| `label` | `kraken-user-role` |
| `assignee_account_id` | `712020:8300527c-0cb7-4412-8303-0306dac20649` |
| `issueTypeName` | `Task` |

**Derive the quarter from the system date:**

```bash
date +"%m %Y"
```

| Month | Quarter |
|---|---|
| 01 – 03 | Q1 |
| 04 – 06 | Q2 |
| 07 – 09 | Q3 |
| 10 – 12 | Q4 |

Example: month `06`, year `2026` → `Q2/26`. Use the last two digits of the year.

Before creating or updating issues, resolve the JIRA option id for that quarter:

1. Fetch issue metadata / edit metadata for the SGP1 issue type being created or updated.
2. Read `customfield_18353` (`Quarters`) allowed values.
3. Select the option whose `value` equals the derived quarter.
4. Set `customfield_18353` with the option object:

```json
[{ "id": "<allowed-value-id>", "value": "<Q derived from system date>" }]
```

Do not use `[{ "name": "<quarter>" }]`; JIRA ignores that shape for this field.

---

## Step 2 — Check for an existing ticket

Search memory for a recent ticket on the same branch or feature:

```
search_episodic_memories(query="jira ticket <branch-or-feature-name> SGP1 kraken")
```

- If a ticket already exists and its description is **incomplete or outdated**, update it with
  `editJiraIssue` — do not create a duplicate.
- If no ticket exists, proceed to create one.

---

## Step 3 — Gather the git diff

Run in parallel:

```bash
git log develop..HEAD --oneline   # to understand scope — do NOT copy into the ticket
git diff develop..HEAD --stat
grep -E '"[a-z-]+":\s*"[0-9]' package.json | head -20  # read real dependency versions
```

Always read version numbers from `package.json` directly — never copy them from commit messages.

Then read the key changed files to understand what was built. Focus on:
- `view.js` / `controller.js` — new UI surfaces, permission flags, conditional renders
- `styles.scss` — new CSS classes and layout changes
- `i18n/*/messages.po` — new user-facing labels
- `*.spec.js` — test coverage added

---

## Step 4 — Build the ticket

### Summary format

```
[auth-admin-fe] <concise imperative description of the main change>
```

Example: `[auth-admin-fe] Add corporate information accordion to userSharedDetail sidebar`

### Description structure (markdown)

```markdown
## Overview
<1–2 sentence summary of what changed and why>

---

## Changes

### <Area 1> (e.g. Desktop sidebar, Mobile panel, Corporate accordion…)
- <bullet per meaningful change>

### <Area 2>
- …

### Tests
- <what test coverage was added or updated>
```

Keep bullets precise and technical. No filler. Do **not** include a list of commits — the description must describe *what* was built, not the git history.

---

## Step 5 — Create or update the ticket

### Create

```
createJiraIssue(
  cloudId:          "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  projectKey:       "SGP1",
  issueTypeName:    "Task",
  summary:          "[auth-admin-fe] …",
  description:      "…",
  contentFormat:    "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels":            ["kraken-user-role"],
    "customfield_18353": [{"id": "<quarter option id>", "value": "<Q derived from system date>"}],
    "customfield_12410": "YYYY-MM-DD"  ← start date, usually today's system date for new tickets
  }
)
```

### Update (if ticket already exists)

Go directly to **Step 7** — do not edit the ticket here. Step 7 handles fetching the current
state, comparing against the diff, and updating parent + subtasks in the correct order.

---

## Step 6 — Create subtasks (new tickets only)

After creating the parent ticket, identify the natural work units from the diff and create
one subtask per area. Typical split for kraken-auth-admin-fe:

- One subtask per major UI surface or feature area (sidebar, accordion, mobile panel, badges…).
- One subtask for dependency bumps if any.
- One subtask for tests covering all the above.

Each subtask must inherit **the same labels, quarter, and start date** as the parent:

```
createJiraIssue(
  cloudId:          "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  projectKey:       "SGP1",
  issueTypeName:    "Sub-task",
  parent:           "SGP1-XXXX",          ← key of the parent ticket
  summary:          "<concise imperative title>",
  description:      "…",
  contentFormat:    "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels":            ["kraken-user-role"],   ← same as parent
    "customfield_18353": [{"id": "<quarter option id>", "value": "<Q derived from system date>"}],
    "customfield_12410": "YYYY-MM-DD"            ← same start date as parent
  }
)
```

Create all subtasks in parallel. Subtask descriptions follow the same structure as the
parent (Overview optional, Changes bullets, no commit list).

---

## Step 7 — Update existing ticket (update path only)

When the user asks to **update** an existing ticket, replace Steps 5–6 with this flow.

### 7a — Fetch current state in parallel

```
getJiraIssue(cloudId, parentKey)               ← parent title + description
getJiraIssue(cloudId, subtask1Key)             ← subtask title + description
getJiraIssue(cloudId, subtask2Key)             ← …
…
```

Fetch all known subtasks in parallel. Use memory (Step 2) or ask the user if the subtask keys are unknown.

### 7b — Re-read the diff

Re-run Step 3 to get the current state of the branch. The code is the source of truth — not what was previously in JIRA.

### 7c — Compare and identify drift

For each element, compare what JIRA has vs what the code shows:

| Element | What to check |
|---|---|
| Parent title | Still accurate? Reflects the full scope of the branch? |
| Parent description | All change areas covered? No outdated bullets? No commit list? |
| Subtask titles | Each title still maps to a real, self-contained work unit? |
| Subtask descriptions | Bullets match actual implementation? No stale details? |
| Coverage | Are there work areas in the diff NOT covered by any existing subtask? |

### 7d — Apply updates in parallel

Update only what has drifted — do not touch fields that are still accurate:

```
editJiraIssue(cloudId, parentKey,   fields: { summary: "…", description: "…" })
editJiraIssue(cloudId, subtask1Key, fields: { summary: "…", description: "…" })
editJiraIssue(cloudId, subtask2Key, fields: { summary: "…", description: "…" })
…
```

Run all `editJiraIssue` calls in parallel.

### 7e — Create missing subtasks

If the diff contains work areas not covered by any existing subtask, create the missing ones
using the same fields as Step 6: `issueTypeName: "Sub-task"`, `parent`, `labels: ["kraken-user-role"]`,
`customfield_18353` (quarter option id/value from system date), and `customfield_12410` (start date —
same value as the parent ticket's start date, read from `getJiraIssue` in step 7a).

---

## Step 8 — Validate parent and subtasks

After creating or updating the parent and all subtasks, fetch every issue and verify:

- `labels` contains `kraken-user-role`
- `customfield_18353` contains the derived quarter value
- `customfield_12410` contains the expected start date

If any field is missing, patch the affected issue before closing the task.

---

## Step 9 — Transition to In Progress (new tickets only)

After creating, move the ticket to **In Progress**:

```
getTransitionsForJiraIssue(cloudId, issueIdOrKey)  →  find "In Progress" transition id
transitionJiraIssue(cloudId, issueIdOrKey, transitionId)
```

Skip this step when updating an existing ticket already in progress.

---

## Step 10 — Save to memory

After a successful create or update, call `search_episodic_memories` to check if an entry
for this ticket already exists. Then:

- **If no entry exists** — call `store_note` or the episodic store with:
  - `title`: `"Ticket JIRA <KEY> para <feature>"`
  - `result`: `"Ticket <KEY> created|updated. Summary: … Subtasks: SGP1-XXXX, … Status: In Progress."`
  - `project`: `"kraken-auth-admin-fe"`
  - `tags`: `["feature", "change"]`

- **If an entry already exists** — update it with the new summary, subtask keys, and status
  so future sessions find accurate information.

---

## Rules

- **NEVER** run `git push`, `git push --force`, or any git upload command.
- Do not create a duplicate if a ticket already exists — update it instead.
- Label `kraken-user-role` is mandatory for every kraken ticket.
- Quarter (`customfield_18353`) must always be set; derive it from `date +"%m %Y"` — never from memory.
- Description must be in **English** (ticket body); skill instructions are in Spanish.
- On update: fetch parent + all subtasks before editing — never update from memory alone.
- On update: run all `editJiraIssue` calls in parallel to minimize round-trips.
- On update: only patch fields that actually changed — do not rewrite accurate content.
