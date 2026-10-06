# Gitea / Forgejo (`tea`, `fj`) quick reference

Prefer `tea` (has review comments, reply, resolve). `fj` covers view/diff/comment/checkout only; use `tea api` or `curl` + token for the rest on Forgejo. Add `-r <owner/repo>` when cwd is not the target.

```bash
# View PR; HEAD_SHA via API (.head.sha), BASE/HEAD refs from .base.ref/.head.ref
tea api repos/{owner}/{repo}/pulls/<N> | jq '{number,title,html_url,head:.head.sha,base:.base.ref,ref:.head.ref}'

# Repo name
tea api repos/{owner}/{repo} | jq -r .full_name

# Check out / diff
tea pulls checkout <N>          # fj pr checkout <N>
tea api repos/{owner}/{repo}/pulls/<N>.diff   # fj pr view <N> diff

# Threads (id, path, line, body, reviewer, resolver); empty resolver = unresolved
tea pulls review-comments <N> -o json

# Reply / resolve (type A only) by review-comment id
tea pulls reply <N> <COMMENT_ID> "<text>"
tea pulls resolve <COMMENT_ID>

# New inline comments: one review with a comments array
tea api -X POST repos/{owner}/{repo}/pulls/<N>/reviews -d '{"commit_id":"<HEAD_SHA>","event":"COMMENT","body":"<summary>","comments":[{"path":"<file>","new_position":<line>,"body":"<body>"}]}'

# Top-level comment
tea comment <N> "<text>"        # fj pr comment <N> "<text>"

# Submit review
tea pulls approve <N> "<body>"
tea pulls reject <N> "<reason>"   # request changes
```

- **Outdated**: `tea` exposes no flag; skip threads with line 0 in the JSON and say so when unsure.
- Review `event` values for the reviews API: `COMMENT`, `APPROVED`, `REQUEST_CHANGES`.
