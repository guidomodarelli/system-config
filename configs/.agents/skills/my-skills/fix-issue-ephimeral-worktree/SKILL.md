---
name: fix-issue-ephimeral-worktree
description: Fix a GitHub or repository issue from a brand-new ephemeral git worktree based on the updated current branch, then create a focused commit, push that same branch, and remove the worktree. Use when the user asks to correct, implement, or address an issue without disturbing the current checkout, especially requests like "fix this issue in an ephemeral worktree, commit, and push", "corrigi esta issue en un worktree efimero", or "take this issue on the current branch, commit, and push".
---

# Fix Issue Worktree

## Contract

- Keep the user's current checkout untouched during investigation and implementation.
- Always create a new and fresh temporary `git worktree` for the task; never reuse an existing worktree or stale directory.
- Ensure the current branch has the latest remote changes before creating the temporary worktree.
- Copy `.env` and `.env.*` files from the original checkout into the fresh worktree before testing, so validation can use the same local environment.
- Link the original checkout's `node_modules` into the fresh worktree when it exists, so dependency installs are not duplicated.
- Do all exploratory implementation work in the fresh temporary `git worktree`.
- Apply the final validated patch back to the original current branch only when ready to commit, and only if it does not overwrite unrelated user changes.
- Use the branch currently checked out in the original repository; do not create, switch to, or choose another branch unless the user explicitly asks for one.
- Create exactly the commits needed for the issue, preferably one focused commit.
- Push the branch after tests pass.
- Remove the temporary worktree after a successful push.
- Never force-push, delete user branches, or discard user changes unless explicitly requested.
- If the issue, repo, current branch, or acceptance criteria are unclear and cannot be inferred from local or GitHub context, ask before editing.

## Workflow

1. Identify the repository root and issue source.
   - Run `git rev-parse --show-toplevel`.
   - Read the issue body and comments from the GitHub app or `gh` when a URL, issue number, or current repo context is available.
   - Confirm the current worktree status with `git status --short`; treat dirty files as user work to preserve.

2. Update the current branch and create a fresh isolated worktree.
   - Fetch the remote with `git fetch origin`.
   - Read the active branch from the original checkout with `git branch --show-current`.
   - If the current checkout is detached, ask which branch to use before editing.
   - Ensure the current branch includes the latest remote changes before starting the fix. Prefer the repo's normal update command when known; otherwise use `git pull --ff-only`.
   - If the current branch is already checked out in the original working tree, do not attempt to check out the same branch in a second worktree. Instead, create a detached worktree from the current `HEAD`, make the fix there, then commit on the original current branch only after applying the final patch back to that branch. Preserve the original dirty state and ask before applying if it would overlap user changes.
   - Create a unique new temporary path outside the current working tree, for example under a sibling `.worktrees/` folder or the OS temp directory.
   - If the intended path already exists, choose a different fresh path. Do not clean or reuse the existing path.
   - Confirm the fresh path is not already listed by `git worktree list`.

```bash
current_branch=$(git branch --show-current)
git fetch origin
git pull --ff-only
worktree_path="../repo-issue-123-$(date +%Y%m%d%H%M%S)"
git worktree add --detach "$worktree_path" "$current_branch"
```

3. Copy local environment files into the worktree.
   - Copy `.env` and every `.env.*` file from the original checkout root into the fresh worktree root before installing, running, or testing.
   - Preserve filenames exactly.
   - Do not copy env files from anywhere outside the original checkout root.
   - Do not stage or commit env files; they are local-only test inputs.
   - If an env file already exists in the fresh worktree for an unexpected reason, do not overwrite it silently. Stop and inspect why the supposedly fresh worktree already has one.

```bash
find . -maxdepth 1 -type f \( -name ".env" -o -name ".env.*" \) -exec cp -p {} "$worktree_path"/ \;
```

4. Link `node_modules` into the worktree when available.
   - If the original checkout root has a `node_modules` directory and the fresh worktree does not, create a link at `<worktree>/node_modules` pointing back to the original checkout's `node_modules`.
   - Prefer a symbolic link on Unix-like shells.
   - On Windows, use a directory junction when symbolic links are unavailable or require elevated permissions.
   - Do not copy `node_modules`.
   - Do not overwrite an existing `node_modules` in the fresh worktree; inspect first if it unexpectedly exists.
   - If linking fails, continue with the repo's normal install command inside the worktree and report that dependencies were not linked.

```bash
if [ -d node_modules ] && [ ! -e "$worktree_path/node_modules" ]; then
  ln -s "$(pwd)/node_modules" "$worktree_path/node_modules"
fi
```

```powershell
$sourceNodeModules = Join-Path (Get-Location) 'node_modules'
$targetNodeModules = Join-Path $worktreePath 'node_modules'
if ((Test-Path -LiteralPath $sourceNodeModules -PathType Container) -and -not (Test-Path -LiteralPath $targetNodeModules)) {
  New-Item -ItemType Junction -Path $targetNodeModules -Target $sourceNodeModules | Out-Null
}
```

5. Implement only inside the worktree.
   - Re-read relevant project instructions from inside the worktree.
   - Inspect existing modules before changing code.
   - Keep edits scoped to the issue and preserve unrelated local changes in the original checkout.
   - Follow any project-specific testing, language, review, and style rules discovered in the worktree.

6. Validate with real commands.
   - Run the smallest relevant test or quality gate that proves the fix.
   - If the issue is a build, lint, runtime, or CI failure, reproduce or run the real failing command when feasible.
   - If validation cannot run, explain the exact command that was skipped and the concrete blocker.

7. Commit on the current branch.
   - Review the diff with `git diff --check`, `git diff`, and `git status --short`.
   - Confirm `.env` and `.env.*` files are not staged.
   - Confirm `node_modules` is not staged.
   - If the worktree is detached because the current branch is already checked out elsewhere, apply the final patch back onto the original current branch before committing.
   - Stage only files belonging to the fix on the current branch.
   - Write a concise commit message that references the issue when useful.

```bash
git add <files>
git commit -m "Fix issue #123 short topic"
```

8. Push the branch.
   - Push with upstream tracking.
   - Do not force-push.

```bash
git push -u origin "$current_branch"
```

9. Close out.
   - Report the worktree path, branch, commit hash, push target, and validation commands.
   - Remove the temporary worktree after the commit and push succeed.
   - Use `git worktree remove <path>` from the original repo and then `git worktree prune` if needed.
   - If removal fails, report the exact remaining path and failure reason.

## Failure Handling

- If the original checkout is dirty, do not copy or reset those changes; leave them alone and work from the current branch in the temporary worktree.
- If the temporary worktree becomes dirty due to an abandoned approach, preserve any useful patch, remove that worktree when safe, and create another fresh worktree. Do not reuse the abandoned path.
- If tests fail because of unrelated existing failures, capture the failure evidence, keep the fix commit limited to the issue, and explain the residual risk.
- If push fails due to auth, permissions, branch protection, or network errors, keep the local commit and report the exact branch, commit, and temporary worktree cleanup status so the user can continue.
