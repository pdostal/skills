---
name: create-or-update-pr
description: Use when the user asks to create or update a PR, MR, merge request, pull request, push a branch, commit and open a review request, or update/amend an existing PR/MR body. Also triggers on phrases like "submit a PR", "raise a pull request", "raise a merge request", "open a review", "draft a PR", "propose my changes", "publish my branch for review", "share my changes for review", "update the PR description", "update the MR description", "open a review request", "create a merge request", "commit and create PR", "do the changes and open a PR", "push to mine and open a PR", "make the changes, commit, push, create PR". Covers commit message conventions, AI label handling, PR/MR body templating, and updating the body of existing PRs/MRs for GitHub, GitLab, Gitea, and Forgejo. Do NOT trigger on a plain "commit" or "commit and push" — those belong to the git-commit skill.
---

# Create or Update PR / MR Skill

## IMPORTANT: Only use this skill when explicitly asked

**Do NOT create a branch or MR/PR when the user asks to "commit" or "commit and push".**
A plain "commit and push" means: commit directly to the current branch and push it.
Only create a new branch and open an MR/PR when the user explicitly says "create a PR",
"open a MR", "merge request", "pull request", or similar.

## Detect the platform

Detect from the git remote URL (or ask if unclear), then load the matching workflow:

| Platform | Tool | Workflow |
|---|---|---|
| GitHub | `gh` | `references/workflow-github.md` |
| GitLab | `glab` | `references/workflow-gitlab.md` |
| Gitea | `tea` | `references/workflow-gitea.md` |
| Forgejo | `fj` | `references/workflow-forgejo.md` |

Per-forge command equivalents: `references/forge-ops.md`. Fall back to `curl` against the API only when the native tool is unavailable or not authenticated.

## Commit messages and push remote

Follow the **git-commit** skill's message format and push-remote selection rules for the
commit you create in Step 1 of the workflow.

## PR / MR body template

See `references/pr-body-template.md` for the full template and formatting rules — required
for every PR/MR body, not just large ones.

## Updating an existing PR/MR body

When the user asks to change or update the PR/MR description, **always read the current body
first** before making any edit ("View body" row in `references/forge-ops.md`). Apply only the requested change on top of the existing
body. Never rewrite from scratch — manual edits made by the author must be preserved.

## Workflow

Load `references/workflow-github.md` or `references/workflow-gitlab.md` (per the detected
platform) and follow it end to end: commit+push, check for an existing open PR/MR, apply the
`AI-Assisted` label, create the PR/MR, post Redmine comments for referenced `poo#` tickets,
auto-hide bot noise, and poll CI.

**Delegating to a subagent?** Do step 1 (commit+push, via the git-commit skill) yourself
first, then hand off the rest of the workflow to the `pr-ops` subagent (`task` tool) — it
has no `git commit`/`git push` access and expects that step already done.
