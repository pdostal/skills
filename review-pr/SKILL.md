---
name: review-pr
description: Use when the user asks to review a PR, check a PR, look at a PR, list PR suggestions, sort out suggestions, address review comments, handle reviewer feedback, implement suggestions, reply to a reviewer, or resolve PR threads. Triggers on phrases like "review PR", "check PR #N", "look at the PR", "there are N suggestions", "sort out suggestions", "address comments", "reply to a reviewer", "implement reviewer feedback", "review MR", "check MR #N", "respond to review comments", "fix reviewer suggestions", "go through the PR comments", "handle feedback", "apply suggestions", "there are review threads", "resolve threads", "leave a review", "post review comments", "look at the feedback", "act on the review".
---

# PR Review & Suggestion Resolution Skill

This skill covers two workflows:
1. **Review mode** — analyse the diff and post inline review comments as a reviewer. See `references/review-mode.md`.
2. **Resolve mode** — list, implement, and reply to existing suggestions/comments left by others. See `references/resolve-mode.md`.

Uses `gh` (GitHub CLI) as the primary tool, with `curl` as fallback. GraphQL/REST call templates for both modes are in `references/graphql-queries.md`.

**Prefer delegating to the `pr-ops` subagent** (`task` tool) to keep this skill's detail
out of the main thread. It has no `git commit`/`git push` access — if resolve mode needs to
commit an implemented suggestion, it will hand control back to you for that step, then
resume.

## Step 1 — Identify the PR and check out the repo

If the user supplied a PR number, URL, or branch name, use that directly. Otherwise
auto-detect from the current branch:

```bash
gh pr view --json number,title,headRefOid,baseRefOid,headRefName,baseRefName,url
```

Capture:
- `PR_NUMBER` — integer PR number
- `HEAD_SHA` — `headRefOid` (the original PR head SHA — use this for all API calls, not any new local commit SHA)
- `BASE_REF` / `HEAD_REF` — branch names
- `REPO` — `gh repo view --json nameWithOwner -q .nameWithOwner`

The current directory is already a checkout of the repository. Never `git clone` into
`/tmp` or elsewhere — work directly here.

1. `git status --porcelain` — if there are unrelated local changes, **stop and ask the
   user** before switching branches. Don't stash/discard automatically.
2. `gh pr checkout $PR_NUMBER` — handles fork-based PRs automatically and re-syncs if
   already checked out.
3. If it fails (not a git repo, or remote mismatch), **ask the user** how to proceed —
   don't silently clone to `/tmp` as a workaround.

## Step 2 — Auto-hide known bot noise (os-autoinst/os-autoinst-distri-opensuse only)

Applies before anything else, in both modes, only when `REPO` is
`os-autoinst/os-autoinst-distri-opensuse` (GitHub). Run `scripts/hide-bot-checklist.sh
<pr_number>`. Do this silently; only mention it to the user if it fails. Skip entirely
for any other repo.

## Step 3 — Fetch review threads (always use GraphQL)

**Always use the GraphQL API** to fetch review threads — the REST comments endpoint
lacks `isResolved` and `isOutdated` fields which are essential for correctly classifying
threads. Query template in `references/graphql-queries.md`.

Classify each thread:

| `isResolved` | `isOutdated` | Action |
|---|---|---|
| `true` | any | **Skip** — already resolved, do not act on it |
| `false` | `true` | **Skip** — comment is on an outdated diff position, already addressed |
| `false` | `false` | **Active** — must be handled |

When listing threads for the user, clearly mark resolved/outdated ones as such so they are not confused with open work.

Then proceed to **Resolve mode** (`references/resolve-mode.md`) for active threads, or
**Review mode** (`references/review-mode.md`) to analyse the diff and post new comments —
whichever the user asked for.

## Error handling

- `gh` not authenticated: run `gh auth status`, report clearly, stop.
- PR not found: report and stop.
- Comment POST fails: print error, continue with remaining threads.
- `HEAD_SHA` missing: `gh pr view $PR_NUMBER --json commits -q '.commits[-1].oid'`
- Commit/push signing failure: ask the user once to run it in their terminal.
