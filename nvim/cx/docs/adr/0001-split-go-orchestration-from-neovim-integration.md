# Split Go orchestration from Neovim integration

The Go CLI owns projects, Task metadata, Git operations, process lifecycle, and Codex session identity. New Lua code under `lua/user/cx/` owns the Neovim menu, terminal buffers, and UI attachment. The integration may call existing public config functions, but it does not modify existing config files. This preserves current editor behavior and accepts some duplicated handoff code where `nmux` keeps its implementation private.
