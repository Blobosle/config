return {
    {
        "mg979/vim-visual-multi",
        enabled=true,
        init = function()
            vim.g.VM_maps = {
                ["Add Cursor Down"] = "<C-S-Down>",
                ["Add Cursor Up"]   = "<C-S-Up>",
            }
        end,
    }
}

