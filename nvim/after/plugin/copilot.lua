vim.g.copilot_no_tab_map = true
vim.keymap.set("i", "<S-Tab>", 'copilot#Accept("<CR>")',
    {expr = true, silent = true, replace_keycodes = false})

