---
name: review-pr
description: Use when the user asks to review a pull request, check a PR, analyse a PR, or post PR review comments. Covers both read-only analysis (plan mode: numbered list of issues) and posting inline GitHub/GitLab/Gitea/Forgejo review comments (build mode). Triggers on phrases like "review PR", "review pull request", "check PR #N", "analyse this PR", "review MR", "review merge request", "check MR #N", "analyse this MR", "post review comments".
---

# PR Review Skill

This skill provides a two-mode pull request review workflow using `gh` (GitHub CLI), `glab` (GitLab CLI), `tea` (Gitea CLI), `fj` (Forgejo CLI) as the
primary tool, with `curl` as fallback.

---

## Step 1 — Identify the PR

If the user supplied a PR number, URL, or branch name, use that directly.

Otherwise auto-detect from the current branch:

```bash
gh pr view --json number,title,headRefOid,baseRefOid,headRefName,baseRefName,url
```

If that fails (not a GitHub repo, not authenticated, no open PR for this branch), report the
error clearly and stop.

Capture:
- `PR_NUMBER` — integer PR number
- `HEAD_SHA` — `headRefOid` (the commit_id required by the review comments API)
- `BASE_REF` / `HEAD_REF` — branch names (for context)
- `REPO` — derived from `gh repo view --json nameWithOwner -q .nameWithOwner`

---

## Step 2 — Fetch the diff

```bash
gh pr diff "$PR_NUMBER"
```

This returns a unified diff with standard `@@` hunk headers. Parse it carefully:

- Each file section starts with `diff --git a/<path> b/<path>`
- The `--- a/<path>` / `+++ b/<path>` lines give you the file path on the new side
- `@@` hunk headers have the form `@@ -OLD_START,OLD_COUNT +NEW_START,NEW_COUNT @@`
- Lines starting with `+` are additions (RIGHT side), `-` are deletions (LEFT side),
  ` ` (space) are context lines

Track the current **new-file line number** as you walk through the diff:
- On a context line: increment new_line counter
- On a `+` line: this is new_line; increment
- On a `-` line: do NOT increment new_line (it doesn't exist in the new file)

This mapping is essential for posting accurate inline comments.

---

## Step 3 — Analyse for issues

Review the diff as a language-agnostic expert code reviewer. Look for, but don't limit to:

- **Bugs** — off-by-one errors, null/nil dereferences, unchecked errors, wrong conditions
- **Security** — injection risks, hardcoded secrets, unsafe deserialization, missing auth checks
- **Logic** — incorrect algorithm, wrong variable used, missing edge case handling
- **Resource management** — unclosed handles, missing defer/finally, memory leaks
- **Concurrency** — race conditions, deadlocks, missing locks
- **API misuse** — wrong HTTP method, missing required fields, deprecated functions
- **Test coverage** — new code paths with no corresponding test additions
- **Style / maintainability** — overly complex logic that could be simplified (only flag if significant)

Focus on the changed lines (`+` lines) but use context lines to understand intent.

Do NOT flag:
- Pure style nits (formatting, naming conventions) unless they cause real problems
- Things that are not visible in the diff

---

## Plan Mode — Print numbered issue list

When running in plan mode (read-only), after analysis print a numbered list in this exact format:

```
PR #<number>: <title>
<url>
Base: <base_ref>  Head: <head_ref>

Found <N> issue(s):

1. [SEVERITY] file/path.ext:<start_line>-<end_line>  <short issue title>

   <start_line-2>:   <context line>
   <start_line-1>:   <context line>
   <start_line>:  +  <affected line(s)>
   ...
   <end_line>:    +  <affected line>

   Problem: <concise explanation of what is wrong and why it matters>
   Suggestion: <one concrete fix or direction>

2. [SEVERITY] ...
```

Severity levels: `[CRITICAL]`, `[HIGH]`, `[MEDIUM]`, `[LOW]`

If no issues are found, say so clearly: "No issues found in PR #N."

---

## Build Mode — Post inline review comments

When running in build mode, post the comments directly without repeating the plan-mode analysis output. If the user switches from plan to build mid-conversation (e.g. says "post suggestions now"), reuse the issues already identified — do not re-analyse the diff.

After analysis (or reusing prior analysis), do the following for each issue:

### Post one inline comment per issue

Use `gh api` to post a pull request review comment pinned to the exact line:

```bash
gh api \
  repos/{owner}/{repo}/pulls/$PR_NUMBER/comments \
  --method POST \
  -f commit_id="$HEAD_SHA" \
  -f path="<file path relative to repo root>" \
  -f side="RIGHT" \
  -F line=<end_line_in_new_file> \
  -f body="<comment body>"
```

For a **line range** (when the issue spans multiple lines), also add:
```bash
  -f start_side="RIGHT" \
  -F start_line=<start_line_in_new_file>
```

Note: `start_line` must be less than `line`. If they are equal, omit `start_line`/`start_side`
and just use `line`.

For issues on **deleted lines** (LEFT side only), use `side=LEFT` and the old-file line number.

**If `gh api` fails** (network error, auth issue, etc.), fall back to `curl`:
```bash
curl -s -X POST \
  -H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER/comments" \
  -d "{
    \"commit_id\": \"$HEAD_SHA\",
    \"path\": \"<path>\",
    \"side\": \"RIGHT\",
    \"line\": <line>,
    \"body\": \"<body>\"
  }"
```

**Comment body format** — keep it concise and actionable. When the fix is a one-to-one line replacement, use GitHub's suggestion block so the author can apply it with one click:

```
<brief explanation of the problem>

```suggestion
<corrected line(s)>
```
```

For issues where a suggestion block is not applicable (e.g. architectural changes, deletions, multi-file fixes), fall back to a short prose comment:

```
**[SEVERITY] Short title**

<explanation of the problem>

<suggested fix or direction>
```

### Anchor strategy when exact line is unavailable

If you cannot determine the precise new-file line number for an issue (e.g. the problem is in
a deleted block), fall back in order:
1. Pin to the nearest `+` or context line in the same hunk
2. Pin to the first line of the relevant file's first hunk
3. Post as a top-level PR comment via `gh pr comment $PR_NUMBER -b "..."`

### Post the overall review summary

After all inline comments are posted, assess the overall severity:

- **CRITICAL or HIGH issues found** → ask the user:
  "Found [N] high/critical issues. Should I submit this as 'request changes' (blocks merge)
  or 'comment' (non-blocking)? [request-changes/comment]"
  Then run accordingly.
- **MEDIUM or LOW issues only** → submit as `--comment` without asking:
  ```bash
  gh pr review "$PR_NUMBER" --comment -b "<summary>"
  ```
- **No issues** → submit as `--approve` (ask the user first):
  "No issues found. Approve the PR? [yes/no]"

Summary body template:
```
## PR Review Summary

Reviewed <N> changed file(s). Found <N_issues> issue(s): <N_crit> critical, <N_high> high, <N_med> medium, <N_low> low.

<One-paragraph overall assessment>

All issues have been posted as inline comments above.
```

---

## Error handling

- If `gh` is not authenticated: `gh auth status` to diagnose, then report clearly.
- If the PR does not exist or is not accessible: report and stop.
- If a comment POST fails, print the error and continue with the remaining issues (do not abort).
- If `HEAD_SHA` cannot be determined, try: `gh pr view $PR_NUMBER --json commits -q '.commits[-1].oid'`

---

## Quick reference — key `gh` commands

```bash
# Auto-detect current branch PR
gh pr view --json number,title,headRefOid,baseRefOid,headRefName,baseRefName,url

# Get repo name
gh repo view --json nameWithOwner -q .nameWithOwner

# Full diff
gh pr diff <PR_NUMBER>

# List changed files
gh pr view <PR_NUMBER> --json files -q '.files[].path'

# Post inline comment (line range)
gh api repos/{owner}/{repo}/pulls/<PR>/comments \
  --method POST \
  -f commit_id=<SHA> -f path=<file> \
  -f side=RIGHT -F start_line=<N> -F line=<M> \
  -f start_side=RIGHT \
  -f body=<text>

# Post inline comment with suggestion block (one-click apply for author)
# body should contain:  ```suggestion\n<corrected lines>\n```

# Post top-level PR comment
gh pr comment <PR_NUMBER> -b "<text>"

# Submit review as comment
gh pr review <PR_NUMBER> --comment -b "<text>"

# Submit review requesting changes
gh pr review <PR_NUMBER> --request-changes -b "<text>"

# Approve
gh pr review <PR_NUMBER> --approve -b "<text>"
```
