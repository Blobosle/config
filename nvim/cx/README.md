# cx

`cx` coordinates persistent Codex Tasks. Git persists source state, Codex persists conversation state, and detached Neovim instances persist editor/runtime state.

## Install

Build the CLI and put it on `PATH`:

```sh
cd ~/.config/nvim/cx
go build -o cx ./cmd/cx
ln -s ~/.config/nvim/cx/cx ~/.local/bin/cx
```

The Neovim integration lives entirely in this directory. The main config adds `~/.config/nvim/cx` to `runtimepath` and calls its public `setup()` function. Normal-mode `<C-i>` opens the Task menu. This intentionally replaces Neovim's default forward-jumplist mapping; `<C-o>` remains the existing nmux session picker.

## Start a Project

Open a terminal inside Neovim, change to the intended Scope root, ensure the whole Git repository is clean, then run:

```sh
cx init
```

`cx init` records the current branch as the Base branch, starts a Project-local Codex app-server, and replaces that terminal shell with the Root Codex session. Running it outside the current Neovim terminal is rejected.

From the Root Codex session, create a Task:

```sh
cx task -m "feat(auth): rotate tokens"
```

The Task receives branch `feat(auth)/rotate-tokens`, a worktree under `.agents/worktrees/feat(auth)/rotate-tokens`, a fork of the Root Codex thread, and its own detached Neovim server. The UI moves to the Task when the current Neovim was launched by the existing nmux-aware shell wrapper.

## Commands

```text
cx init
cx task -m <message>
cx list [--global] [--json]
cx attach <root-or-task>
cx send <task> <message>
cx diff <task>
cx rebase [task] [--continue]
cx land [task] [--continue] [-m <message>] [--remove]
cx remove <task>
```

There is deliberately no `cx fork`: only the Root Codex session may ask the Project app-server to fork its thread, and it does that as part of `cx task`.

Landing requires clean Root and Task worktrees and must be run by the owning Task Codex session. It creates a backup ref, rewrites the Task as one commit, rebases it onto the local Base branch, and fast-forwards the Base branch. Conflicts remain in the Task worktree; resolve them with the same Codex session, then run `cx land --continue`. Landing does not fetch, pull, or run tests.

## Storage

- Task worktrees: `<git-root>/.agents/worktrees/<branch>`
- Project metadata: `${XDG_STATE_HOME:-~/.local/state}/cx/projects/<project-id>`
- Sockets: `/tmp/cx-<uid>/<short-project-id>`

Metadata is atomic JSON. A per-Project file lock serializes mutations. `cx` never adopts or overwrites a branch it did not create.
