# Land Tasks as one fast-forward commit

The owning Task Codex runs `cx land` only after committing every Task change. `cx` creates a backup ref, squashes the Task tree to one commit using the Task message, rebases that commit onto the current local Base branch, and fast-forwards the clean Root. A conflict remains paused in the Task Git worktree for the same Task Codex to resolve with `cx land --continue`. Landing does not fetch remote changes, run tests, or remove the Task unless the caller passes `--remove`.
