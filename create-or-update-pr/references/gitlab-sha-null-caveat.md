# GitLab caveat — MR created with no diff (sha: null)

## Root cause

`glab mr create` auto-detects the head repo by inspecting **all** git remotes.
If a personal fork remote exists (e.g. `mine → pdostal/repo`) alongside `origin`
(`qac/repo`), `glab` may pick the fork as the head repo and call
`CreateMergeRequest` against it. GitLab then cannot correlate the push to
`origin` with that MR, so `diff_refs` and `sha` remain `null` indefinitely.

The same issue can theoretically occur on GitHub or other platforms when
multiple remotes are configured.

## Detection

After creating the MR, verify `sha` is not null:

```bash
glab api "projects/{namespace}%2F{repo}/merge_requests/{iid}" --hostname {host} \
  | python3 -m json.tool | grep '"sha"'
# → "sha": "abc123..."   OK
# → "sha": null          broken — follow recovery steps below
```

## Recovery (if sha is still null)

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
     -f remove_source_branch=true
   ```
5. Verify `sha` again — it should resolve immediately when using the raw API.
