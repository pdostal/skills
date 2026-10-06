# GitLab (`glab`) quick reference

`glab mr note` is marked experimental; if a subcommand misbehaves use `glab api` (REST). Add `-R <group/repo>` when cwd is not the target.

```bash
# Auto-detect MR from current branch; HEAD_SHA = diff_refs.head_sha (use for all position-based calls)
glab mr view -F json --jq '{iid,title,url:.web_url,source_branch,target_branch,diff_refs}'

# Repo name
glab repo view -F json --jq .path_with_namespace

# Check out (handles forks)
glab mr checkout <IID>

# Full diff
glab mr diff <IID> --color=never

# Threads: unresolved diff discussions as JSON (discussion `id`, notes[].body/position/resolved)
glab mr note list <IID> --type diff --state unresolved -F json

# Reply to a thread (>= 8-char discussion id prefix)
glab mr note create <IID> --reply <DISCUSSION_ID> -m "<text>"

# Resolve a thread (type A suggestions only)
glab mr note resolve <DISCUSSION_ID> <IID>

# New inline comment (latest diff version); range: --line 10:15; removed line: --old-line N
glab mr note create <IID> --file <path> --line <N> -m "<body>"

# Top-level comment
glab mr note create <IID> -m "<text>"
```

- **Outdated**: GitLab has no flag. A thread is outdated when its note `position.head_sha` differs from the MR's current `diff_refs.head_sha`, or `position` is null. Treat as skip, same as GitHub.
- **Suggestions**: body fenced with `` ```suggestion:-0+0 `` (lines above/below via `-N+M`), not plain `suggestion`.
- **Review summary**: no `--comment`/`--request-changes`. Post a top-level note; `glab mr approve <IID>` to approve. Batch inline comments with `--draft` then `glab mr note publish <IID>`.
- **Fallback REST**: `glab api "projects/<ns>%2F<repo>/merge_requests/<iid>/discussions"`; resolve with `-X PUT ".../discussions/<id>" -f resolved=true`.
