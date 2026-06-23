---
name: create-or-update-pr
description: Use when the user asks to create or update a PR, MR, merge request, pull request, push a branch, commit and open a review request, or update/amend an existing PR/MR body. Covers commit message conventions, AI label handling, PR/MR body templating, and updating the body of existing PRs/MRs for GitHub, GitLab, Gitea, and Forgejo.
---

# Create or Update PR / MR Skill

## IMPORTANT: Only use this skill when explicitly asked

**Do NOT create a branch or MR/PR when the user asks to "commit" or "commit and push".**
A plain "commit and push" means: commit directly to the current branch and push it.
Only create a new branch and open an MR/PR when the user explicitly says "create a PR",
"open a MR", "merge request", "pull request", or similar.

## Native CLI tools

Always prefer the native CLI tool for the platform. Fall back to `curl` against the API only when the native tool is unavailable or not authenticated.

| Platform | Tool |
|---|---|
| GitHub | `gh` |
| GitLab | `glab` |
| Gitea | `tea` |
| Forgejo | `fj` |

Detect the platform from the git remote URL if not told explicitly.

## Commit messages

Git commit messages follow the **Conventional Commits** specification. The PR/MR title does **not** — it should be plain English (no `type:` prefix).

```
type(scope): short imperative subject

Optional brief body — one or two sentences max. Explain *what* and *why*,
not *how*. Skip the body entirely if the subject line is self-explanatory.
```

- Types: `feat`, `fix`, `ci`, `test`, `chore`, `docs`, `refactor`, `perf`, `style`
- Subject line: lowercase, imperative mood, no trailing period, ≤72 chars
- Body: brief — avoid padding, filler phrases, or restating the diff

## AI label

Before opening the PR/MR, check whether the platform/repository supports labels.

1. List existing labels and look for one named `AI-Assisted` (case-insensitive).
2. If it does not exist, create it (use a neutral color, e.g. `#lightblue` / `#a8d8ea`).
3. Apply the `AI-Assisted` label to the PR/MR.

```bash
# GitHub — list labels
gh label list

# GitHub — create label if missing
gh label create "AI-Assisted" --color "a8d8ea" --description "Created with AI assistance"

# GitHub — apply when creating PR
gh pr create --label "AI-Assisted" ...

# GitLab — list labels
glab label list

# GitLab — create label if missing
glab label create "AI-Assisted" --color "#a8d8ea" --description "Created with AI assistance"

# GitLab — apply when creating MR
glab mr create --label "AI-Assisted" ...
```

## PR / MR body template

```
$SHORT_EXPLANATION_IN_SINGLE_PARAGRAPH

- Related tickets: [poo#123](https://progress.opensuse.org/issues/123), [bsc#456](https://bugzilla.suse.com/show_bug.cgi?id=456), ...
- Related merge requests: !123, !456, ...
- Verification runs: [run name](url), ...

## Commits

- `abc1234` feat: add user login
- `def5678` fix: handle null session
- `ghi9012` style: run linter

The `style` commit (`ghi9012`) is an automated linting pass and can be ignored. The `fix` commit (`def5678`) changes auth logic and warrants a separate look.
```

Rules:
- The opening paragraph must be a single, concise paragraph — no bullet points, no headers.
- The PR/MR title must be plain English — do not apply the `type(scope):` conventional commit prefix to it.
- Omit the `Related tickets` line entirely if no tickets are provided.
- Omit the `Related merge requests` line entirely if no related MRs/PRs are provided.
- Omit the `Verification runs` line entirely if no runs are provided.
- Do not include placeholder lines for missing sections.
- Omit the `## Commits` section entirely if there is only one commit.
- Populate the `## Commits` list using `git log <base>..<branch> --oneline`; use the short hash and full subject line for each entry.
- After the list, add a single prose sentence (or two at most) noting: any `style`-type commits that reviewers can ignore (automated formatting/linting), and any distinct `feat`, `fix`, or `refactor` commits that warrant a separate look.
- Omit the summary sentence if all commits are of the same logical type and none need special attention.

## Remote selection

Always inspect all configured git remotes before pushing:

```bash
git remote -v
```

- If a remote named **`mine`** exists, **always push to `mine`** and use its URL to derive `<namespace>/<repo>` for the PR/MR head.
- Fall back to `origin` only when `mine` does not exist.

```bash
# Prefer 'mine', fall back to 'origin'
PUSH_REMOTE=$(git remote | grep -q '^mine$' && echo mine || echo origin)
PUSH_URL=$(git remote get-url "$PUSH_REMOTE")
# e.g. git@github.com:pdostal/repo.git  →  pdostal/repo
```

## Workflow

1. Stage and commit with a conventional commit message.
2. Determine the push remote (see **Remote selection** above).
3. Push the branch to the chosen remote: `git push <push-remote> <branch>`
4. Check for an already-open PR/MR on this branch:
   ```bash
   # GitHub
   gh pr list --head <branch> --state open

   # GitLab
   glab mr list --source-branch <branch> --state opened
   ```
   If one exists:
   - Inspect which remote/fork the existing PR's head branch is pushed to (GitHub: `gh pr view <number> --json headRepositoryOwner,headRefName`; GitLab: check `source_project_id`).
   - If the existing PR head matches the remote you just pushed to, show the PR to the user and **ask what to do**:
     - **(a) Push onto the existing PR** — the commit appears in the open PR automatically. Do not open a new one. Then re-evaluate the PR/MR body: regenerate the `## Commits` section based on the updated commit range and update the PR/MR body accordingly.
       ```bash
       # GitHub — update body
       gh pr edit <number> --body "<updated body>"

       # GitLab — update body
       glab mr update <iid> --description "<updated body>"
       ```
     - **(b) Open a new PR anyway** — proceed with the steps below.
     - **(c) Abort** — stop here.
     Wait for the user's answer before continuing.
   - If the existing PR head points to a **different** remote/fork than the one you pushed to, inform the user of the mismatch and ask how to proceed before continuing.
5. Check for the `AI-Assisted` label; create it if missing.
6. Create the MR/PR with auto-delete of the source branch on merge enabled where supported, and with `--head <namespace>/<repo>` derived from the chosen push remote (see GitLab caveat below):
   ```bash
   # GitLab — --remove-source-branch enables auto-delete on merge
   glab mr create \
     --source-branch <branch> \
     --target-branch master \
     --head <namespace>/<repo> \
     --title "<title>" \
     --description "<body>" \
     --label "AI-Assisted" \
     --remove-source-branch

   # GitHub — --delete-branch enables auto-delete on merge
   gh pr create \
     --head <branch> \
     --base master \
     --title "<title>" \
     --body "<body>" \
     --label "AI-Assisted" \
     --delete-branch
   ```
7. Verify the MR has a resolved `sha` (see GitLab caveat below).
8. If `sha` is null: recover using the steps in the caveat section.
9. **Check the CI pipeline** — wait for it to start, then poll until it finishes:
   ```bash
   # GitLab
   glab api "projects/{namespace}%2F{repo}/merge_requests/{iid}/pipelines" \
     | python3 -c "import json,sys; d=json.JSONDecoder(); o,_=d.raw_decode(sys.stdin.read()); [print(p['id'],p['status']) for p in o[:1]]"
   ```
   - If the pipeline **passes**: return the MR URL to the user.
   - If the pipeline **fails**: fetch the failed job log and diagnose:
     ```bash
     # Get failed job id
     glab api "projects/{namespace}%2F{repo}/pipelines/{pipeline_id}/jobs" \
       | python3 -c "import json,sys; d=json.JSONDecoder(); o,_=d.raw_decode(sys.stdin.read()); [print(j['id'],j['status'],j['name']) for j in o]"
     # Get log
     glab api "projects/{namespace}%2F{repo}/jobs/{job_id}/trace"
     ```
   - If the failure is **trivial** (e.g. commit message style, lint error introduced by the new commits): fix it immediately — amend or rebase the commits, force-push, and re-poll the pipeline.
   - If the failure is **non-trivial** (pre-existing infrastructure issue, flaky runner, unrelated test): report it to the user and return the MR URL without blocking.
10. Return the MR URL to the user.

## GitLab caveat — MR created with no diff (sha: null)

### Root cause

`glab mr create` auto-detects the head repo by inspecting **all** git remotes.
If a personal fork remote exists (e.g. `mine → pdostal/repo`) alongside `origin`
(`qac/repo`), `glab` may pick the fork as the head repo and call
`CreateMergeRequest` against it. GitLab then cannot correlate the push to
`origin` with that MR, so `diff_refs` and `sha` remain `null` indefinitely.

The same issue can theoretically occur on GitHub or other platforms when
multiple remotes are configured.

### Prevention

Always pass `--head <namespace>/<repo>` where `<namespace>/<repo>` is derived
from the chosen push remote URL (prefer `mine` over `origin`). Extract it with:

```bash
PUSH_REMOTE=$(git remote | grep -q '^mine$' && echo mine || echo origin)
git remote get-url "$PUSH_REMOTE"
# e.g. gitlab@gitlab.suse.de:pdostal/repo.git  →  pdostal/repo
```

### Detection

After creating the MR, verify `sha` is not null:

```bash
glab api "projects/{namespace}%2F{repo}/merge_requests/{iid}" --hostname {host} \
  | python3 -m json.tool | grep '"sha"'
# → "sha": "abc123..."   OK
# → "sha": null          broken — follow recovery steps below
```

### Recovery (if sha is still null)

1. Close the broken MR: `glab mr close {iid} --repo {namespace}/{repo}`
2. Amend the commit to produce a new SHA: `git commit --amend --no-edit --reset-author`
3. Force-push: `git push --force <push-remote> <branch>`
4. Recreate via the raw API (bypasses remote auto-detection entirely):
   ```bash
   glab api "projects/{namespace}%2F{repo}/merge_requests" --hostname {host} -X POST \
     -f source_branch="<branch>" \
     -f target_branch="master" \
     -f title="<title>" \
     -f "description=<body>" \
     -f labels="AI-Assisted" \
     -f should_remove_source_branch=true
   ```
5. Verify `sha` again — it should resolve immediately when using the raw API.
