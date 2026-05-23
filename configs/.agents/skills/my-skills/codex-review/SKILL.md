---
name: codex-review
description: "Codex code review closeout: local dirty changes, PR branch vs main, parallel tests."
---

# Codex Review

Run Codex's built-in code review as a closeout check. This is code review (`codex review`), not Guardian `auto_review` approval routing.

Use when:
- user asks for Codex review / autoreview / second-model review
- after non-trivial code edits, before final/commit/ship
- reviewing a local branch or PR branch after fixes

## Contract

- Treat review output as advisory. Never blindly apply it.
- Verify every finding by reading the real code path and adjacent files.
- Read dependency docs/source/types when the finding depends on external behavior.
- Reject unrealistic edge cases, speculative risks, broad rewrites, and fixes that over-complicate the codebase.
- Prefer small fixes at the right ownership boundary; no refactor unless it clearly improves the bug class.
- Keep going until every launched Codex review process has exited and every completed review reports no accepted/actionable findings.
- When Codex review reports accepted/actionable findings, enter the mandatory loop: review -> verify findings -> fix accepted/actionable findings -> run relevant tests -> rerun review -> repeat until every launched review process exits with 0 accepted/actionable findings.
- Never stop after reporting findings with a passive closeout such as "No hice cambios; esto fue solo review." If there are accepted/actionable findings, fix them before ending the task unless the user explicitly asks to review only or forbids changes.
- If every reported finding is rejected after verification, document the rejection reason and rerun Codex review only when the code or review target changed; otherwise close with the verified rejection summary.
- If a review-triggered fix changes code, rerun focused tests and rerun Codex review.
- Stop only after the selected review command/helper and any `codex review` process it launches have all exited with no accepted/actionable findings. Do not run an extra direct `codex review` just to get a nicer "clean" line, a second opinion, or clearer closeout wording.
- Treat the helper's successful exit plus absence of actionable findings as the clean review result only when there is also no still-running related `codex review` process from that run.
- Do not terminate a running review only because it becomes quiet, including when the CLI appears to launch a nested `codex review`. Keep the original exec session alive and wait for the full process tree to exit.
- If a nested or long-running review has no new output for several minutes, inspect or poll the running process tree and keep waiting while related `codex review`/`codex` child processes still exist. Do not stop any launched review process unless the user explicitly asks or the environment forcibly terminates it.
- It is terminally forbidden to interrupt a nested or repeated `codex review` process yourself and close with wording such as "the last review did not print a final clean line; I inspected the process tree, confirmed recursion, and interrupted it to avoid dangling processes." That is not an acceptable closeout. The valid choices are to keep waiting until the launched process tree exits, follow an explicit user stop request, or report that the environment forcibly terminated the run.
- If rejecting a finding as intentional/not worth fixing, add a brief inline code comment only when it explains a real invariant or ownership decision that future reviewers should know.
- Do not push just to review. Push only when the user requested push/ship/PR update.

## Pick Target

Dirty local work:

```bash
codex review --uncommitted
```

Use this only when the patch is actually unstaged/staged/untracked in the
current checkout. For committed, pushed, or PR work, review the branch against
its base instead; do not force `--mode local` / `--uncommitted` just because the
helper docs mention dirty work first. A clean `--uncommitted` review only proves
there is no local patch.

Branch/PR work:

```bash
git fetch origin
codex review --base origin/main
```

Do not pass an inline prompt with `--base`; current CLI rejects `--base` + `[PROMPT]` even though help text is ambiguous. If custom instructions are needed, run the plain base review first, then do a local/manual follow-up pass.

If an open PR exists, use its actual base:

```bash
base=$(gh pr view --json baseRefName --jq .baseRefName)
codex review --base "origin/$base"
```

Committed single change:

```bash
codex review --commit HEAD
```

## Parallel Closeout

Format first if formatting can change line locations. Then it is OK to run tests and review in parallel:

```bash
scripts/codex-review --parallel-tests "<focused test command>"
```

Tradeoff: tests may force code changes that stale the review. If tests or review lead to code edits, rerun the affected tests and rerun review until every launched review process exits with no accepted/actionable findings. Once that rerun exits cleanly and no related review process remains alive, stop; do not spend another long review cycle on redundant confirmation.

## Context Efficiency

Codex review is usually noisy. Default to a subagent filter when subagents are available. Ask it to run the review and return only:
- actionable findings it accepts
- findings it rejects, with one-line reason
- exact files/tests to rerun

Run inline only for tiny changes or when subagents are unavailable.

## Long-Running Or Nested Reviews

- Start exactly one review command for the selected target and wait for that command plus every `codex review --uncommitted`, `codex review --base`, or helper invocation it launches internally to finish.
- Do not start a second review command while the first one is still running.
- Do not kill nested review processes merely to avoid leaving sessions open. Prefer polling the existing exec session and process tree until every related review process exits.
- Keep user updates brief during quiet periods, but do not convert quiet output into a failure by itself.
- Repeated plugin warnings, validation chatter, or lack of a final clean/no-findings line are not evidence of success and are not reasons to stop while any launched review process is still alive.
- If the run is suspected to be stuck, gather evidence such as parent/child process status and elapsed time, then keep waiting while related review processes are alive. A run is clean only after all launched review processes exit and the final observed result is 0 accepted/actionable findings.
- Do not present a self-interrupted nested review as an "honest partial closeout." Self-interruption is a contract violation unless it was requested by the user; the final report must say the review contract was not satisfied, not frame the interruption as responsible cleanup.

## Helper

Bundled helper:

```bash
~/.codex/skills/codex-review/scripts/codex-review --help
```

If installed from `agent-scripts`, path is:

```bash
/Users/steipete/Projects/agent-scripts/skills/codex-review/scripts/codex-review --help
```

The helper:
- chooses dirty `--uncommitted` first
- otherwise uses current PR base if `gh pr view` works
- otherwise uses `origin/main` for non-main branches
- should be left in `--mode auto` or forced to `--mode branch` for committed/PR work; do not force `--mode local` after committing
- writes only to stdout unless `--output` or `CODEX_REVIEW_OUTPUT` is set
- supports `--dry-run` and `--parallel-tests`
- prints `codex-review clean: no accepted/actionable findings reported` when the selected review command exits 0; before reporting that as clean, confirm no related launched `codex review` process remains alive

## Final Report

Include:
- review command used
- tests/proof run
- findings accepted/rejected, briefly why
- the clean review result from the final helper/review run after all launched review processes exited, or why a remaining finding was consciously rejected

Do not run another Codex review solely to improve the final report wording. If the final helper run exited 0, produced no accepted/actionable findings, and left no related launched review process alive, report that exact run as clean.
