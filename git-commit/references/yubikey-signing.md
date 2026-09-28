# YubiKey / SSH signing errors (`agent refused operation`)

Always run `git commit` with `GIT_TRACE=1` so signing failures are visible immediately
rather than silently swallowed:

```bash
GIT_TRACE=1 git commit -m "..."
```

If the output contains `agent refused operation` or `Couldn't sign message`:

1. Tell the user: **"Please touch your YubiKey."**
2. **Immediately retry** the exact same command — do not wait for the user to confirm it
   succeeded first. The YubiKey touch unblocks the SSH agent and the retry will succeed.
3. If the retry also fails, ask the user to run the command themselves in their terminal
   (where the agent interaction is working) and wait for confirmation.

Do **not** ask the user to run the command in their terminal on the first failure — they
are present and will touch the key.

`GIT_TRACE=1` is a useful one-off diagnostic prefix — do **not** recommend setting it
permanently in the environment or `.gitconfig`. It is very noisy across all git operations.

## Other failures

If the failure reason is unclear, check `GIT_TRACE=1` output and report the error to the
user clearly before stopping.
