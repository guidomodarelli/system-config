---
name: kraken-jira-ticket
description: >
  Creates or updates a JIRA ticket in the Kraken / Shipping Groot project (SGP1) for work
  done in fury_kraken-auth-admin-fe. Reads project configuration from MCP memory, builds
  the ticket description from the git branch diff, and transitions it to In Progress.
  Use when the user asks to create, open, or log a JIRA ticket for changes in the
  kraken-auth-admin-fe repository.
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
    "customfield_18353": [{"name": "<Q derived from system date>"}]  ← derive with `date +"%m %Y"`
  }
)
```

### Update (if ticket already exists)

```
editJiraIssue(
  cloudId:       "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  issueIdOrKey:  "SGP1-XXXX",
  contentFormat: "markdown",
  fields: {
    "summary":     "…",
    "description": "…"
  }
)
```

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
    "customfield_18353": [{"name": "<Q derived from system date>"}],  ← same as parent
    "customfield_10015": "YYYY-MM-DD"            ← same start date as parent
  }
)
```

Create all subtasks in parallel. Subtask descriptions follow the same structure as the
parent (Overview optional, Changes bullets, no commit list).

---

## Step 8 — Transition to In Progress (new tickets only)

After creating, move the ticket to **In Progress**:

```
getTransitionsForJiraIssue(cloudId, issueIdOrKey)  →  find "In Progress" transition id
transitionJiraIssue(cloudId, issueIdOrKey, transitionId)
```

Skip this step when updating an existing ticket already in progress.

---

## Step 9 — Save to memory

After a successful create or update, store an episodic note so future sessions can find it:

```
store_episodic / update memory:
  title:   "Ticket JIRA <KEY> para <feature>"
  result:  "Ticket <KEY> <created|updated>. Summary: … Status: In Progress."
  project: "kraken-auth-admin-fe"
  tags:    ["feature", "change"]
```

---

## Rules

- **NEVER** run `git push`, `git push --force`, or any git upload command.
- Do not create a duplicate if a ticket already exists — update it instead.
- Label `kraken-user-role` is mandatory for every kraken ticket.
- Quarter (`customfield_18353`) must always be set; read current quarter from memory.
- Description must be in **English** (ticket body); skill instructions are in Spanish.
