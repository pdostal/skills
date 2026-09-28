# GitLab workflow

Uses `glab`. Commit message format and push-remote selection follow the **git-commit** skill.

## AI label

1. `glab label list` — check for `AI-Assisted` (case-insensitive).
2. If missing: `glab label create "AI-Assisted" --color "#a8d8ea" --description "Created with AI assistance"`.
3. Apply when creating the MR: `glab mr create --label "AI-Assisted" ...`.

## Steps

1. Commit (git-commit skill conventions) and push to the chosen remote: `git push <push-remote> <branch>`.
   (Running as the `pr-ops` subagent: skip this — the primary already committed and pushed before delegating to you. Start at step 2.)
2. Check for an already-open MR on this branch: `glab mr list --source-branch <branch> --state opened`.
   If one exists:
   - Inspect its `source_project_id`.
   - If it matches the remote you just pushed to, show the MR and **ask what to do**:
     (a) push onto it — regenerate the `## Commits` section (`./pr-body-template.md`) and update
     via `glab mr update <iid> --description "<updated body>"`;
     (b) open a new MR anyway;
     (c) abort. Wait for the answer.
   - If it points to a different remote/fork, tell the user and ask how to proceed.
3. Ensure the `AI-Assisted` label exists (see above), apply it.
4. Create the MR with `--head <namespace>/<repo>` derived from the chosen push remote — this avoids the
   GitLab `sha: null` bug (see `./gitlab-sha-null-caveat.md`):
   ```bash
   # --remove-source-branch enables auto-delete on merge
   glab mr create \
     --source-branch <branch> --target-branch master --head <namespace>/<repo> \
     --title "<title>" --description "<body>" --label "AI-Assisted" --remove-source-branch
   ```
   Confirm delete-on-merge is actually set (the flag above usually suffices, but verify via API):
   ```bash
   glab api "projects/{namespace}%2F{repo}/merge_requests/{iid}" -X PUT -f remove_source_branch=true
   ```
   If this fails (e.g. insufficient permissions), note it and continue.
5. Verify the MR has a resolved `sha`. If `sha` is null, follow `./gitlab-sha-null-caveat.md`.
6. **Post a Redmine comment** on every `poo#NNN` ticket referenced in the MR body/commits:
   ```bash
   echo "$PR_BODY" | grep -oP 'poo#\K[0-9]+'
   ```
   For each, add a journal note via the `redmine-progress-opensuse-org_update_redmine_issue` MCP tool
   (`fields.notes: "Fix submitted via <PR_URL>"`). Fall back to curl against the Redmine API if the MCP
   tool is unavailable. Don't abort the workflow if this fails — log and continue.
7. Return the MR URL to the user.
8. **Check the CI pipeline** — wait for it to start, then poll until it finishes:
   ```bash
   glab api "projects/{namespace}%2F{repo}/merge_requests/{iid}/pipelines" \
     | python3 -c "import json,sys; d=json.JSONDecoder(); o,_=d.raw_decode(sys.stdin.read()); [print(p['id'],p['status']) for p in o[:1]]"
   ```
   - **Passes**: tell the user.
   - **Fails**: fetch the failed job log and diagnose:
     ```bash
     glab api "projects/{namespace}%2F{repo}/pipelines/{pipeline_id}/jobs" \
       | python3 -c "import json,sys; d=json.JSONDecoder(); o,_=d.raw_decode(sys.stdin.read()); [print(j['id'],j['status'],j['name']) for j in o]"
     glab api "projects/{namespace}%2F{repo}/jobs/{job_id}/trace"
     ```
     - **Trivial** (commit-message style, lint error introduced by the new commits): fix immediately —
       amend/rebase, force-push, re-poll.
     - **Non-trivial** (pre-existing infra issue, flaky runner, unrelated test): report to the user.
