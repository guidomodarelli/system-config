---
name: kraken-jira-ticket
description: >
  Creates or updates a JIRA ticket (parent + subtasks) in the Kraken / Shipping Groot project
  (SGP1) for work from any Git repository. Discovers repository identity and default branch,
  builds ticket scope from the branch diff, creates or synchronizes parent and subtasks,
  validates mandatory SGP1 fields, and transitions merged PR work to Done. Use when the user asks
  to create, update, or sync a Kraken JIRA ticket from current repository changes.
---

# Kraken JIRA Ticket

Create or update a ticket in **SGP1 — Shipping Groot** from current Git repository changes.
Requires Atlassian MCP and memory MCP.

> **NEVER run `git push` or any git upload command during this skill.**
> Ticket management is independent of repository state.

---

## ⛔ MANDATORY FIELDS — every issue (parent AND every subtask)

Every `createJiraIssue` and every `editJiraIssue` (when creating/completing an issue)
**MUST** carry ALL of these. None is optional. There is no valid ticket without the three:

| Field | Key | Value | Source |
|---|---|---|---|
| **Labels** | `labels` | `["kraken-user-role"]` + PR label when applicable | fixed + PR association |
| **Quarter** | `customfield_18353` | `[{"id": "<option id>", "value": "<Qx/yy>"}]` | derived from `date +"%m %Y"` (Step 1) |
| **Start date** | `customfield_12410` | `"YYYY-MM-DD"` | first commit date on the branch (new) / parent's value (subtasks & updates) |

### PR association label

When the user provides a PR number (explicitly or via context), add the label
`<repository_id>/PR-<number>` to all issues (parent and every subtask).

Format: `<repository_id>/PR-<number>` — e.g. `groot-ui/PR-42`.

The labels array becomes: `["kraken-user-role", "<repository_id>/PR-<number>"]`.

This label enables fast JQL lookup in Step 2 to detect if a ticket already exists for that PR,
avoiding duplicates without relying solely on memory.

Rules that are NOT negotiable:

- **Never** create or finalize an issue with any of these three missing.
- **Every subtask inherits all three** — same labels, same quarter, same start date as the parent.
- When a PR label is present, **every subtask also carries it** — same as the parent.
- Quarter is **always** resolved fresh from the system date — never from memory, never guessed.
- Quarter uses the option-object shape `[{"id","value"}]` — never `[{"name":...}]`.
- If you cannot resolve the quarter option id, **stop and resolve it** (Step 1) before creating anything.
- The task is **not done** until Step 8 confirms all three fields on the parent and every subtask.

Do not skip these because the diff is small, the user asked only for "a quick ticket",
or the fields "seem obvious". They are enforced on 100% of issues.

---

## Step 1 — Resolve repository context, fixed JIRA config, and quarter

Resolve repository root and identifiers before reading diffs or creating tickets:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
```

If remote HEAD is unavailable, choose first existing branch in this order: `develop`, `main`,
`master`. Stop and ask only when none exists.

Resolve `repository_id` in this order:

1. Non-empty `application_name` from `<repo-root>/.fury`.
2. `name` from `<repo-root>/package.json`, removing npm scope when present.
3. Git root directory basename, removing a leading `fury_` or `fury-`.

Use `repository_id` for JIRA summary prefix (`[<repository_id>]`) and memory project. Never
hardcode a repository name and never ask for confirmation only because repository differs from
previous skill executions.

SGP1 config is fixed:

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

### Resolve PR state when a PR number or link is known

Before looking up, creating, updating, or transitioning the ticket, read the current PR state:

```bash
gh pr view <PR_NUMBER> --json state -q .state
```

Store the exact result as `PR_STATE`. GitHub returns `OPEN`, `CLOSED`, or `MERGED`.

- `MERGED` means the parent JIRA ticket must finish in **Done** through the complete ordered path
  defined in Step 9.
- Any other state follows the existing **In Progress** behavior for new tickets.
- Never infer merge state from branch existence, commit history, local refs, or memory.
- If `gh pr view` fails, retry once with
  `gh api repos/{owner}/{repo}/pulls/<PR_NUMBER> --jq '.merged_at != null'`. Treat `true` as
  `MERGED`. If both checks fail, stop before changing JIRA status and report that PR state could
  not be verified.
- When no PR number or link is known, set `PR_STATE` to unknown and keep the existing new-ticket
  behavior; do not transition an existing ticket to Done without verified `MERGED` state.

---

## Step 2 — Check for an existing ticket

### 2a — JQL lookup by PR label (preferred, when PR number is known)

When a PR number is provided, query JIRA directly — this is faster and deterministic:

```
searchJiraIssuesUsingJql(
  cloudId: "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  jql: "project = SGP1 AND labels = \"<repository_id>/PR-<number>\" AND issuetype = Task",
  fields: ["summary", "status", "labels", "subtasks"]
)
```

- If results found → ticket already exists. Go to **Step 7** (update path).
- If no results → proceed to 2b or create a new ticket.

### 2b — Memory fallback (when no PR number or JQL returns nothing)

Search memory for a recent ticket on the same branch or feature:

```
search_episodic_memories(
  query="jira ticket <repository_id> <branch-or-feature-name> SGP1 kraken",
  project="<repository_id>"
)
```

- If a ticket already exists and its description is **incomplete or outdated**, update it with
  `editJiraIssue` — do not create a duplicate.
- If no ticket exists, proceed to create one.

---

## Step 3 — Gather the git diff

Run in parallel with resolved `BASE_BRANCH`:

```bash
git log "$BASE_BRANCH"..HEAD --oneline
git diff "$BASE_BRANCH"..HEAD --stat
git diff "$BASE_BRANCH"..HEAD --name-only
git log "$BASE_BRANCH"..HEAD --reverse --format="%aI" | head -1   ← first commit date (ISO)
test -f package.json && grep -E '"[a-z-]+":\s*"[0-9]' package.json | head -20
```

Extract the **first commit date** (the earliest commit on the branch since it diverged from
`BASE_BRANCH`). Use the `YYYY-MM-DD` portion as the start date for new tickets.

Use commits only to understand scope; never copy commit lists into ticket. Read version numbers
from manifest files directly, never from commit messages.

Read representative changed files by responsibility:

- Production code: components, routes, controllers, services, hooks, utilities, configuration.
- Presentation: styles, templates, stories, assets, user-facing copy.
- Contracts: public types, schemas, API definitions, manifests, migrations.
- Validation: unit, integration, E2E tests, fixtures, snapshots.
- Documentation and release metadata when changed.

Do not assume framework, language, folder layout, or package manager from repository name.

---

## Step 4 — Build the ticket

### Summary format

`[<repository_id>] <concise imperative description of the main change>`

Example: `[groot-ui] Unify search debounce defaults at 500 ms`

### Description structure (markdown)

```markdown
## Overview
<1–2 sentence summary of what changed and why>

---

## Changes

### <Area 1>
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
  summary:          "[<repository_id>] …",
  description:      "…",
  contentFormat:    "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels":            ["kraken-user-role", "<repository_id>/PR-<number>"],  ← add PR label when PR number is known
    "customfield_18353": [{"id": "<quarter option id>", "value": "<Q derived from system date>"}],
    "customfield_12410": "YYYY-MM-DD"  ← start date = first commit date on the branch (from Step 3)
  }
)
```

> When no PR number is provided, omit the PR label — `labels` stays as `["kraken-user-role"]` only.

### Update (if ticket already exists)

Go directly to **Step 7** — do not edit the ticket here. Step 7 handles fetching the current
state, comparing against the diff, and updating parent + subtasks in the correct order.

---

## Step 6 — Create subtasks (new tickets only)

After creating parent, identify natural work units from actual diff and create one subtask per
cohesive area. Common splits:

- One subtask per independent production-code area or public behavior.
- One subtask for contract, configuration, migration, or dependency work when substantial.
- One subtask for tests and documentation when they form meaningful work units.

Avoid empty bookkeeping subtasks and avoid assuming UI work.

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
    "labels":            ["kraken-user-role", "<repository_id>/PR-<number>"],   ← same as parent (include PR label when applicable)
    "customfield_18353": [{"id": "<quarter option id>", "value": "<Q derived from system date>"}],
    "customfield_12410": "YYYY-MM-DD"            ← same start date as parent
  }
)
```

Create all subtasks in parallel. Subtask descriptions follow the same structure as the
parent (Overview optional, Changes bullets, no commit list).

After creating parent and subtasks, display the created tickets as a summary table:

```
| # | Key | Type | Summary |
|---|---|---|---|
| 1 | [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234) | 📋 Parent | [groot-ui] Unify search debounce defaults at 500 ms |
| 2 | [SGP1-1235](https://mercadolibre.atlassian.net/browse/SGP1-1235) | 📎 Subtask | Add debounce utility with configurable delay |
| 3 | [SGP1-1236](https://mercadolibre.atlassian.net/browse/SGP1-1236) | 📎 Subtask | Update search components to use shared debounce |
| 4 | [SGP1-1237](https://mercadolibre.atlassian.net/browse/SGP1-1237) | 📎 Subtask | Add unit tests for debounce behavior |
```

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
using the same fields as Step 6: `issueTypeName: "Sub-task"`, `parent`, `labels: ["kraken-user-role", "<repository_id>/PR-<number>"]` (include PR label when applicable),
`customfield_18353` (quarter option id/value from system date), and `customfield_12410` (start date —
same value as the parent ticket's start date, read from `getJiraIssue` in step 7a).

After updating/creating, display all tickets (updated and new) as a summary table:

```
| # | Key | Type | Action | Summary |
|---|---|---|---|---|
| 1 | [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234) | 📋 Parent | ✏️ Updated | [groot-ui] Unify search debounce defaults at 500 ms |
| 2 | [SGP1-1235](https://mercadolibre.atlassian.net/browse/SGP1-1235) | 📎 Subtask | ✏️ Updated | Add debounce utility with configurable delay |
| 3 | [SGP1-1236](https://mercadolibre.atlassian.net/browse/SGP1-1236) | 📎 Subtask | — No change | Update search components to use shared debounce |
| 4 | [SGP1-1237](https://mercadolibre.atlassian.net/browse/SGP1-1237) | 📎 Subtask | 🆕 Created | Add integration tests for debounce edge cases |
```

Use `✏️ Updated` for modified issues, `🆕 Created` for new ones, `— No change` for untouched.

---

## Step 8 — Validate parent and subtasks (BLOCKING GATE)

This step is mandatory and blocking. The task is **not complete** until it passes.

After creating or updating the parent and all subtasks, fetch **every** issue
(`getJiraIssue` on the parent and each subtask, in parallel) and verify on each one:

- [ ] `labels` contains `kraken-user-role`
- [ ] `labels` contains `<repository_id>/PR-<number>` (when PR number was provided)
- [ ] `customfield_18353` contains the derived quarter (correct `id` + `value`)
- [ ] `customfield_12410` contains the expected start date

If **any** field is missing or wrong on **any** issue, patch that issue with `editJiraIssue`
and re-fetch to confirm. Do not close the task until all checks pass on every issue.

Report the result as a markdown table:

```
| Issue | Type | Label | PR Label | Quarter | Start Date |
|---|---|---|---|---|---|
| [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234) | parent | ✅ | ✅ groot-ui/PR-42 | ✅ Q3/26 | ✅ 2026-07-07 |
| [SGP1-1235](https://mercadolibre.atlassian.net/browse/SGP1-1235) | subtask | ✅ | ✅ groot-ui/PR-42 | ✅ Q3/26 | ✅ 2026-07-07 |
| [SGP1-1236](https://mercadolibre.atlassian.net/browse/SGP1-1236) | subtask | ✅ | ✅ groot-ui/PR-42 | ✅ Q3/26 | ✅ 2026-07-07 |
```

Use ✅ for present/correct, ❌ for missing/wrong. When no PR number was provided, show `➖` in the PR Label column.

---

## Step 9 — Transition parent according to PR state

Transitions apply to the **parent ticket only**. Fetch its current status before every transition
and never move it backwards.

### PR is not verified as merged

For a newly created ticket, keep the existing **Backlog → To Do → In Progress** flow:

```
transitionJiraIssue(cloudId, issueIdOrKey, { id: "331" })   ← "To Do" (status id 10000)
transitionJiraIssue(cloudId, issueIdOrKey, { id: "71" })    ← "Start progress" → In Progress
```

| Step | Transition name | Transition id | Target status |
|---|---|---|---|
| 1 | To Do | 331 | To Do (10000) |
| 2 | Start progress | 71 | In Progress (12834) |

- Transition 71 is only available from "To Do" — step 1 is required first.
- If transition 331 is unavailable, use 51 ("Selected to Development") — same target status 10000.
- Skip statuses the parent has already reached.
- Do not change the status of an existing ticket unless `PR_STATE` is verified as `MERGED`.
- Confirm a new ticket reached **In Progress**.

### PR_STATE is MERGED — transition to Done

A verified merged PR must leave the parent in **Done**, whether the ticket was created now or
already existed. Follow this ordered status path:

```
To Do → In Progress → Create New Release → Done
```

1. Fetch the parent with `getJiraIssue` and read its exact current status.
2. If it is before **To Do**, apply transition 331; if unavailable, apply 51.
3. Re-fetch. If it is **To Do**, apply transition 71 to reach **In Progress**.
4. Re-fetch and call `getTransitionsForJiraIssue`. Select the available transition whose name or
   target status is exactly `Create New Release`, then pass its returned id to
   `transitionJiraIssue`.
5. Re-fetch and call `getTransitionsForJiraIssue` again. Select the available transition whose
   target status is exactly `Done`, then pass its returned id to `transitionJiraIssue`.
6. Re-fetch the parent and block completion until its status is exactly **Done**.

Rules:

- Resolve the `Create New Release` and `Done` transition ids from JIRA at execution time; do not
  guess or hardcode ids that were not returned for the current issue.
- If the parent already occupies a status in the ordered path, resume from that status and skip
  completed steps. If it is already **Done**, perform no transition and only verify it.
- Never jump directly from **In Progress** to **Done**. **Create New Release** is mandatory.
- After each transition, re-fetch the parent before resolving the next transition.
- If an expected transition is unavailable or a transition does not reach its expected status,
  stop, report the current status and available transition names, and do not claim completion.

---

## Step 9b — Update PR description with Jira link (MANDATORY when PR number/link was provided)

After creating or updating the ticket, insert the Jira link into the PR description body
immediately after the first heading (title line), without modifying any other content.

This step is **mandatory** — do not skip it when a PR number or link was provided.

1. Read current PR body: `gh pr view <PR_NUMBER> --json body -q .body`
2. If the body already contains the Jira link → skip.
3. Find the first line that starts with `#` (the main title/heading).
4. Insert `🎫 Jira: [<KEY>](https://mercadolibre.atlassian.net/browse/<KEY>)` on the **very next line** after that heading (with a blank line before and after for separation).
5. The Jira link MUST go immediately after the first heading — never at the top, never at the bottom, never in any other position.
6. Update: `gh pr edit <PR_NUMBER> --body "<modified body>"`

Example result in PR body:

```markdown
## Summary
🎫 Jira: [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234)

<rest of existing description unchanged>
```

Rules:
- **Mandatory** when a PR number or PR link was explicitly provided by the user.
- Position is non-negotiable: always immediately after the first `#` heading.
- Do not touch the existing PR body content — only insert the Jira line.
- If the PR body already contains the Jira link, skip (do not duplicate).
- Format: `🎫 Jira: [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234)`

---

## Step 10 — Save to memory

After a successful create or update, call `search_episodic_memories` to check if an entry
for this ticket already exists. Then:

- **If no entry exists** — call `store_note` or the episodic store with:
  - `title`: `"Ticket JIRA <KEY> para <feature>"`
  - `result`: `"Ticket <KEY> created|updated. Summary: … Subtasks: SGP1-XXXX, … Status: <verified final status>. PR state: <PR_STATE>."`
  - `project`: `"<repository_id>"`
  - `tags`: `["feature", "change"]`

- **If an entry already exists** — update it with the new summary, subtask keys, and status
  so future sessions find accurate information.

---

## Rules

- **NEVER** run `git push`, `git push --force`, or any git upload command.
- Do not create a duplicate if a ticket already exists — update it instead.
- **The three mandatory fields (labels, quarter, start date) go on EVERY issue — parent and every subtask. No exceptions.** See the "MANDATORY FIELDS" block at the top.
- Label `kraken-user-role` is mandatory for every kraken ticket.
- **PR association label** (`<repository_id>/PR-<number>`) is mandatory when a PR number is provided. It goes on parent AND every subtask. Format: lowercase repo id, `/PR-`, number (e.g. `groot-ui/PR-42`).
- When a PR number is known, resolve `PR_STATE` from GitHub before changing JIRA status; never infer `MERGED` from local Git state or memory.
- When `PR_STATE` is `MERGED`, the parent must finish in **Done** through **To Do → In Progress → Create New Release → Done**; never skip **Create New Release**.
- When a PR number is known, Step 2a (JQL lookup by PR label) takes precedence over memory search.
- Quarter (`customfield_18353`) must always be set; derive it from `date +"%m %Y"` — never from memory. Use the `[{"id","value"}]` shape.
- Start date (`customfield_12410`) must always be set: first commit date on the branch for new tickets (derived from `git log BASE_BRANCH..HEAD --reverse --format="%aI" | head -1`), the parent's value for subtasks and updates.
- Every subtask inherits the parent's labels (including PR label when present), quarter, and start date — verify this, don't assume the API copies them.
- Step 8 is a **blocking gate**: never close the task until all fields are confirmed present on the parent and every subtask.
- Description must be in **English** (ticket body); skill instructions are in Spanish.
- Repository identity, base branch, file layout, language, and framework must be discovered from
  current checkout; none may be hardcoded.
- On update: fetch parent + all subtasks before editing — never update from memory alone.
- On update: run all `editJiraIssue` calls in parallel to minimize round-trips.
- On update: only patch fields that actually changed — do not rewrite accurate content, but always re-verify the mandatory fields survived.
