return {
    {
        "mbbill/undotree",
        init = function()
            local undodir = vim.fn.stdpath("state") .. "/undo"
            vim.fn.mkdir(undodir, "p")
            vim.opt.undodir = undodir
            vim.opt.undofile = true
        end,
        keys = {
            { "<leader>u", vim.cmd.UndotreeToggle, desc = "Toggle Undotree" },
        },
        cmd = { "UndotreeToggle", "UndotreeFocus", "UndotreeHide", "UndotreeShow" },
    },
}
