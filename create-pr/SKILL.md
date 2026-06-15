---
name: create-pr
description: Use when the user asks to create a PR, MR, merge request, pull request, push a branch, or commit and open a review request. Covers commit message conventions, AI label handling, and PR/MR body templating for GitHub, GitLab, Gitea, and Forgejo.
---

# Create PR / MR Skill

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
```

Rules:
- The opening paragraph must be a single, concise paragraph — no bullet points, no headers.
- The PR/MR title must be plain English — do not apply the `type(scope):` conventional commit prefix to it.
- Omit the `Related tickets` line entirely if no tickets are provided.
- Omit the `Related merge requests` line entirely if no related MRs/PRs are provided.
- Omit the `Verification runs` line entirely if no runs are provided.
- Do not include placeholder lines for missing sections.

## Workflow

1. Stage and commit with a conventional commit message.
2. Push the branch to `origin`: `git push origin <branch>`
3. Determine `<namespace>/<repo>` from the `origin` remote URL.
4. Check for the `AI-Assisted` label; create it if missing.
5. Create the MR with `--head <namespace>/<repo>` to force the correct head repo (see GitLab caveat below):
   ```bash
   glab mr create \
     --source-branch <branch> \
     --target-branch master \
     --head <namespace>/<repo> \
     --title "<title>" \
     --description "<body>" \
     --label "AI-Assisted"
   ```
6. Verify the MR has a resolved `sha` (see GitLab caveat below).
7. If `sha` is null: recover using the steps in the caveat section.
8. Return the MR URL to the user.

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
from the `origin` remote URL. Extract it with:

```bash
git remote get-url origin
# e.g. gitlab@gitlab.suse.de:qac/qac-openqa-yaml.git  →  qac/qac-openqa-yaml
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
3. Force-push: `git push --force origin <branch>`
4. Recreate via the raw API (bypasses remote auto-detection entirely):
   ```bash
   glab api "projects/{namespace}%2F{repo}/merge_requests" --hostname {host} -X POST \
     -f source_branch="<branch>" \
     -f target_branch="master" \
     -f title="<title>" \
     -f "description=<body>" \
     -f labels="AI-Assisted"
   ```
5. Verify `sha` again — it should resolve immediately when using the raw API.
