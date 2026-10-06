# GitHub workflow

Uses `gh`. Commit message format and push-remote selection follow the **git-commit** skill.

## AI label

1. `gh label list` — check for `AI-Assisted` (case-insensitive).
2. If missing: `gh label create "AI-Assisted" --color "a8d8ea" --description "Created with AI assistance"`.
3. Apply when creating the PR: `gh pr create --label "AI-Assisted" ...`.

## Steps

1. Commit (git-commit skill conventions) and push to the chosen remote: `git push <push-remote> <branch>`.
   (Running as the `pr-ops` subagent: skip this — the primary already committed and pushed before delegating to you. Start at step 2.)
2. Check for an already-open PR on this branch: `gh pr list --head <branch> --state open`.
   If one exists:
   - Inspect its head repo: `gh pr view <number> --json headRepositoryOwner,headRefName`.
   - If it matches the remote you just pushed to, show the PR and **ask what to do**:
     (a) push onto it — regenerate the `## Commits` section (`./pr-body-template.md`) and update via `gh pr edit <number> --body "<updated body>"`;
     (b) open a new PR anyway;
     (c) abort. Wait for the answer.
   - If it points to a different remote/fork, tell the user and ask how to proceed.
3. Ensure the `AI-Assisted` label exists (see above), apply it.
4. Create the PR:
   ```bash
   # No --delete-branch flag exists; --base defaults to the repo default branch
   gh pr create --head <branch> --title "<title>" --body "<body>" --label "AI-Assisted"
   ```
   Then enable delete-on-merge at the repo level (per-PR API doesn't exist for this on GitHub):
   ```bash
   gh api "repos/{owner}/{repo}" -X PATCH -f delete_branch_on_merge=true
   ```
   If this fails (e.g. insufficient permissions), note it and continue.
5. **Post a Redmine comment** on every `poo#NNN` ticket referenced in the PR body/commits:
   ```bash
   echo "$PR_BODY" | grep -oP 'poo#\K[0-9]+'
   ```
   For each, add a journal note via the `redmine-progress-opensuse-org_update_redmine_issue` MCP tool
   (`fields.notes: "Fix submitted via <PR_URL>"`). Fall back to curl against the Redmine API if the MCP
   tool is unavailable. Don't abort the workflow if this fails — log and continue.
6. **Auto-hide known bot noise** (`os-autoinst/os-autoinst-distri-opensuse` only) — run
   `../scripts/hide-bot-checklist.sh <pr_number>` before the CI wait loop below. Do this silently; only
   mention failures. Skip for any other repo.
7. Return the PR URL to the user.
8. **Check the CI pipeline** — wait for it to start, then poll until it finishes:
   ```bash
   gh pr checks <pr_number> --watch
   ```
   - **Passes**: tell the user.
   - **Fails**: fetch the failed run's log and diagnose:
     ```bash
     gh run view <run_id> --log-failed
     ```
     - **Trivial** (commit-message style, lint error introduced by the new commits): fix immediately —
       amend/rebase, force-push, re-poll.
     - **Non-trivial** (pre-existing infra issue, flaky runner, unrelated test): report to the user.
