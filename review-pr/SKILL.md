---
name: review-pr
description: Use when the user asks to review a PR, check a PR, look at a PR, list PR suggestions, sort out suggestions, address review comments, handle reviewer feedback, implement suggestions, reply to a reviewer, or resolve PR threads. Triggers on phrases like "review PR", "check PR #N", "look at the PR", "there are N suggestions", "sort out suggestions", "address comments", "reply to a reviewer", "implement reviewer feedback", "review MR", "check MR #N", "respond to review comments", "fix reviewer suggestions", "go through the PR comments", "handle feedback", "apply suggestions", "there are review threads", "resolve threads", "leave a review", "post review comments", "look at the feedback", "act on the review".
---

# PR Review & Suggestion Resolution Skill

This skill covers two workflows:
1. **Review mode** — analyse the diff and post inline review comments as a reviewer.
2. **Resolve mode** — list, implement, and reply to existing suggestions/comments left by others.

Uses `gh` (GitHub CLI) as the primary tool, with `curl` as fallback.

---

## Step 1 — Identify the PR

If the user supplied a PR number, URL, or branch name, use that directly.

Otherwise auto-detect from the current branch:

```bash
gh pr view --json number,title,headRefOid,baseRefOid,headRefName,baseRefName,url
```

Capture:
- `PR_NUMBER` — integer PR number
- `HEAD_SHA` — `headRefOid` (the original PR head SHA — use this for all API calls, not any new local commit SHA)
- `BASE_REF` / `HEAD_REF` — branch names
- `REPO` — `gh repo view --json nameWithOwner -q .nameWithOwner`

---

## Step 1.5 — Use the existing checkout in the current directory (do not clone elsewhere)

The current directory is already a checkout of the repository. Never `git clone` into
`/tmp` or any other location for this skill — work directly in the current directory.

1. Check for uncommitted changes first:
   ```bash
   git status --porcelain
   ```
   If there are unrelated local changes, **stop and ask the user** how to
   proceed before switching branches. Do not stash or discard anything
   automatically.
2. Check out and sync the PR's head branch — this handles fork-based PRs
   automatically (adds/uses the correct remote) and re-syncs if the branch
   is already checked out:
   ```bash
   gh pr checkout $PR_NUMBER
   ```
3. If `gh pr checkout` fails because the current directory isn't a git repo,
   or its remote doesn't match the PR's repo, **ask the user** how to
   proceed — do not silently clone to `/tmp` as a workaround.

---

## Step 1.6 — Auto-hide known bot noise (os-autoinst/os-autoinst-distri-opensuse only)

Applies before anything else, in both Review mode and Resolve mode, only when `REPO` is `os-autoinst/os-autoinst-distri-opensuse` (GitHub). Skip entirely for any other repo.

Check for an issue comment authored by `github-actions[bot]` whose body starts with `Great PR! Please pay attention to the following items before merging:`. This is a top-level issue comment, not a review thread, so it won't show up in the Step 2 GraphQL query — check it separately:

```bash
gh api graphql -f query='
{
  repository(owner: "os-autoinst", name: "os-autoinst-distri-opensuse") {
    pullRequest(number: '"$PR_NUMBER"') {
      comments(first: 50) {
        nodes { id isMinimized author { login } body }
      }
    }
  }
}' --jq '.data.repository.pullRequest.comments.nodes[]
  | select(.author.login=="github-actions" or .author.login=="github-actions[bot]")
  | select(.body | startswith("Great PR! Please pay attention to the following items before merging:"))
  | select(.isMinimized == false)
  | .id'
```

For each `id` returned, minimize it with reason `RESOLVED`:

```bash
gh api graphql -f query='
mutation {
  minimizeComment(input: {subjectId: "<COMMENT_NODE_ID>", classifier: RESOLVED}) {
    minimizedComment { isMinimized minimizedReason }
  }
}'
```

Do this silently; only mention it to the user if the mutation fails.

---

## Step 2 — Fetch review threads (always use GraphQL)

**Always use the GraphQL API** to fetch review threads — the REST comments endpoint lacks `isResolved` and `isOutdated` fields which are essential for correctly classifying threads.

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 30) {
        nodes {
          id
          isResolved
          isOutdated
          comments(first: 10) {
            nodes {
              databaseId
              author { login }
              body
              path
              line
              originalLine
            }
          }
        }
      }
    }
  }
}'
```

Classify each thread:

| `isResolved` | `isOutdated` | Action |
|---|---|---|
| `true` | any | **Skip** — already resolved, do not act on it |
| `false` | `true` | **Skip** — comment is on an outdated diff position, already addressed |
| `false` | `false` | **Active** — must be handled |

When listing threads for the user, clearly mark resolved/outdated ones as such so they are not confused with open work.

---

## Resolve Mode — Handle active threads

For each **active** thread:

### A. Code suggestions (suggestion block in body)

Implement the suggestion directly in the source file. Then:

1. Run the project linter on the modified file (see git-commit skill).
2. Commit using the git-commit skill conventions. Use `GIT_TRACE=1` if commit output is suppressed to diagnose failures.
3. If commit or push fails due to GPG/SSH signing (YubiKey), **ask the user once** to run the command in their terminal. Do not retry in a loop.
4. Reply to the thread (see Replying below).
5. Resolve the thread using the GraphQL `resolveReviewThread` mutation with the `id` (`PRRT_...`) captured in Step 2:

```bash
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "<PRRT_...id>"}) {
    thread { isResolved }
  }
}'
```

Only resolve threads where the suggestion was fully implemented. Do **not** resolve type B (general comment) threads — those are for the reviewer to close.

### B. General comments (not a suggestion block)

Read the comment carefully. Implement what's needed, or if it's a discussion point, reply explaining the decision. Keep the reply to **1 sentence** (2–3 only if genuinely needed).

### Replying to a thread

Post the reply using `in_reply_to` with the original `HEAD_SHA` (not a new commit SHA):

```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments \
  --method POST \
  -f commit_id="$HEAD_SHA" \
  -f path="<file>" \
  -f side="RIGHT" \
  -F line=<line> \
  -F in_reply_to=<databaseId of first comment in thread> \
  -f body="<reply>"
```

Reply style: **brief and direct** — 1 sentence max, 2–3 only if genuinely required.

Examples of good replies:
- `"Done, added \`-L\`."`
- `"Removed the hint comment — the recommendation is already in variables.md."`
- `"Implemented — now detects http(s):// URLs and fetches with curl; falls back to base64 otherwise."`

### Commit strategy for resolved suggestions

- Group trivial fixes (single-line changes, comment removals) into one commit per logical topic.
- Implement non-trivial suggestions (new features, behaviour changes) as **separate commits**.
- Follow the git-commit skill for message format, linting, and signing.

---

## Review Mode — Analyse diff and post comments as reviewer

### Fetch the diff

```bash
gh pr diff "$PR_NUMBER"
```

Parse carefully:
- `diff --git a/<path> b/<path>` — file section start
- `@@ -OLD_START,OLD_COUNT +NEW_START,NEW_COUNT @@` — hunk header
- `+` lines — additions (RIGHT side); `-` lines — deletions (LEFT side); ` ` — context

Track the **new-file line number**:
- Context line: increment
- `+` line: this is new_line, increment
- `-` line: do NOT increment

### What to look for

- **Bugs** — off-by-one, null dereferences, unchecked errors, wrong conditions
- **Security** — injection risks, hardcoded secrets, missing auth checks
- **Logic** — wrong algorithm, wrong variable, missing edge cases
- **Resource management** — unclosed handles, memory leaks
- **Concurrency** — race conditions, deadlocks
- **API misuse** — wrong HTTP method, deprecated functions
- **Test coverage** — new code paths with no tests

Do NOT flag pure style nits or things not visible in the diff.

### Plan Mode — print issue list

```
PR #<number>: <title>
<url>
Base: <base_ref>  Head: <head_ref>

Found <N> issue(s):

1. [SEVERITY] file/path.ext:<start_line>-<end_line>  <short title>

   <context lines>
   <start_line>:  +  <affected line>

   Problem: <concise explanation>
   Suggestion: <concrete fix>
```

Severity: `[CRITICAL]`, `[HIGH]`, `[MEDIUM]`, `[LOW]`

### Build Mode — post inline comments

```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments \
  --method POST \
  -f commit_id="$HEAD_SHA" \
  -f path="<file>" \
  -f side="RIGHT" \
  -F line=<end_line> \
  -f body="<body>"
```

For line ranges add `-f start_side="RIGHT" -F start_line=<N>` (only when start < end).

For deleted lines use `side=LEFT` and the old-file line number.

Use GitHub suggestion blocks for one-to-one line fixes:
````
<brief explanation>

```suggestion
<corrected line(s)>
```
````

**Fallback anchor strategy** (when exact line unavailable):
1. Nearest `+` or context line in the same hunk
2. First line of the file's first hunk
3. Top-level comment: `gh pr comment $PR_NUMBER -b "..."`

### Overall review summary

- **CRITICAL/HIGH** → ask user: request-changes or comment?
- **MEDIUM/LOW only** → submit as `--comment` automatically
- **No issues** → ask user before approving

```bash
gh pr review "$PR_NUMBER" --comment -b "## PR Review Summary\n\n..."
gh pr review "$PR_NUMBER" --request-changes -b "..."
gh pr review "$PR_NUMBER" --approve -b "..."
```

---

## Error handling

- `gh` not authenticated: run `gh auth status`, report clearly, stop.
- PR not found: report and stop.
- Comment POST fails: print error, continue with remaining threads.
- `HEAD_SHA` missing: `gh pr view $PR_NUMBER --json commits -q '.commits[-1].oid'`
- Commit/push signing failure: ask the user once to run it in their terminal.

---

## Quick reference

```bash
# Auto-detect PR
gh pr view --json number,title,headRefOid,baseRefOid,headRefName,baseRefName,url

# Repo name
gh repo view --json nameWithOwner -q .nameWithOwner

# Check out the PR branch locally (in the current directory, handles forks automatically)
gh pr checkout <PR_NUMBER>

# Full diff
gh pr diff <PR_NUMBER>

# Review threads with resolved/outdated status (always use this over REST)
gh api graphql -f query='{ repository(owner:"O", name:"R") { pullRequest(number:N) {
  reviewThreads(first:30) { nodes { id isResolved isOutdated
    comments(first:10) { nodes { databaseId author{login} body path line originalLine } }
  } } } } }'

# Reply to thread
gh api repos/{owner}/{repo}/pulls/<PR>/comments --method POST \
  -f commit_id=<HEAD_SHA> -f path=<file> -f side=RIGHT -F line=<N> \
  -F in_reply_to=<comment_databaseId> -f body="<text>"

# Resolve a thread (type A suggestions only — use the PRRT_... node id from Step 2)
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "<PRRT_...id>"}) {
    thread { isResolved }
  }
}'

# Top-level comment
gh pr comment <PR_NUMBER> -b "<text>"

# Submit review
gh pr review <PR_NUMBER> --comment -b "<body>"
gh pr review <PR_NUMBER> --request-changes -b "<body>"
gh pr review <PR_NUMBER> --approve -b "<body>"
```
