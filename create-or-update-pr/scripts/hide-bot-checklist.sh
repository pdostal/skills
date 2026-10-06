#!/bin/sh
# Minimize the github-actions[bot] "Great PR!" checklist comment.
# No-op (exit 0) outside os-autoinst/os-autoinst-distri-opensuse. Usage: hide-bot-checklist.sh <pr_number>
set -eu
PR_NUMBER="$1"
[ "$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" = "os-autoinst/os-autoinst-distri-opensuse" ] || exit 0

ids=$(gh api graphql -f query='
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
  | .id')

for id in $ids; do
  gh api graphql -f query='
  mutation {
    minimizeComment(input: {subjectId: "'"$id"'", classifier: RESOLVED}) {
      minimizedComment { isMinimized minimizedReason }
    }
  }'
done
