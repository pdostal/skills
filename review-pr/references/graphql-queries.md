# GraphQL / API quick reference

```bash
# Auto-detect PR
gh pr view --json number,title,headRefOid,baseRefOid,headRefName,baseRefName,url

# Repo name
gh repo view --json nameWithOwner -q .nameWithOwner

# Check out the PR branch locally (in the current directory, handles forks automatically)
gh pr checkout <PR_NUMBER>

# Full diff
gh pr diff <PR_NUMBER>

# Review threads with resolved/outdated status (always use this over REST —
# the REST comments endpoint lacks isResolved/isOutdated)
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
            nodes { databaseId author { login } body path line originalLine }
          }
        }
      }
    }
  }
}'

# Reply to thread (use the original HEAD_SHA, not a new commit SHA)
gh api repos/{owner}/{repo}/pulls/<PR>/comments --method POST \
  -f commit_id=<HEAD_SHA> -f path=<file> -f side=RIGHT -F line=<N> \
  -F in_reply_to=<comment_databaseId> -f body="<text>"

# Resolve a thread (type A suggestions only — use the PRRT_... node id)
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
