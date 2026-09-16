# Store Task worktrees under the Git root

`cx` stores Task Git worktrees in `<git-root>/.agents/worktrees/`. A Task path mirrors its derived branch path, such as `.agents/worktrees/feat/add-login`. Keeping Task checkouts with their repository makes them easy to locate and lets nested Projects share one worktree directory. During initialization, `cx` adds this directory to the repository's private `.git/info/exclude` file so Task files do not make the Root dirty or alter the tracked `.gitignore`.
