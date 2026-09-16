# Initialize Projects from a Neovim terminal

`cx init` succeeds only when it runs inside a terminal owned by a live Neovim instance. It registers that editor as the Project Root and starts the Root Codex session in the same terminal. This makes the existing Neovim process the persistent Root instead of launching or adopting an editor through another path.
