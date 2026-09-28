# Rewording existing commits

To reword the last N commits without changing their content:

```bash
GIT_SEQUENCE_EDITOR="sed -i 's/^pick/reword/g'" git rebase -i HEAD~N
# Then for each commit stopped:
git commit --amend -m "new message"
git rebase --continue
```

If the editor is unavailable (e.g. `vi: No such file or directory`), the rebase will pause at each commit — use `git commit --amend -m "..."` then `git rebase --continue`.
