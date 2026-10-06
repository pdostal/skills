# Forge operations

Flags verified against `--help`, not against live forges. Add `--repo` (`-R` for `glab`; `-r` for `tea`/`fj`)
when the cwd remote is not the target. `<n>` is the PR number (MR iid on GitLab).

| Op | `gh` | `glab` | `tea` | `fj` |
|---|---|---|---|---|
| Open PR for branch | `gh pr list --head <b> --state open` | `glab mr list --source-branch <b>` | `tea pulls ls` (filter by head) | `fj pr search` (filter by head) |
| View body | `gh pr view <n> --json body -q .body` | `glab mr view <n> -F json --jq .description` | `tea pulls <n> -f body -o simple` | `fj pr view <n> body` |
| Create | `gh pr create --head <b> --title T --body-file F --label L` | `glab mr create -s <b> --head <ns>/<repo> -t T --description-file F -l L --remove-source-branch` | `tea pulls create --head <b> -t T --description-file F -L L` | `fj pr create --head <b> --body-file F "T"` |
| Edit body | `gh pr edit <n> --body-file F` | `glab mr update <n> --description-file F` | `tea pulls edit <n> --description-file F` | `fj pr edit <n> body` (editor) |
| Ensure label | `gh label list` / `gh label create` | `glab label list` / `glab label create` | `tea labels ls` / `tea labels create --name` | `fj repo labels view` / `fj repo labels create <name> <color>` |
| Add label later | `gh pr edit <n> --add-label L` | `glab mr update <n> -l L` | `tea pulls edit <n> -L L` | `fj pr edit <n> labels -a L` |
| Comment | `gh pr comment <n> --body-file F` | `glab mr note create <n> -m "..."` | `tea comment <n> "..."` | `fj pr comment <n> --body-file F` |
| CI | `gh pr checks <n> --watch` | `glab ci status` / pipelines API | n/a: `tea api` + commit status | `fj pr status <n> --wait` |
| Delete branch on merge | `gh api repos/{owner}/{repo} -X PATCH -f delete_branch_on_merge=true` | `--remove-source-branch` | `tea api` PATCH `default_delete_branch_after_merge` (repo setting) | n/a: repo setting in web UI |

- Omit `--base`/`--target-branch` unless targeting a non-default branch: all four default to the repo's default branch.
- Where the cell says "(editor)" or "n/a", ask the user or fall back to the REST API (`tea api`, or `curl` with a token) instead of guessing.
- `fj` has no `--body-file` on `edit`; prefer `fj pr view`/REST for reads and ask before replacing a body interactively.
