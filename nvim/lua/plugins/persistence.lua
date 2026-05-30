return {
    {
        "folke/persistence.nvim",
        event = "BufReadPre",
        opts = {
            vim.keymap.set("n", "<leader>R", function() require("persistence").load({ last = true }) end)
        }
    }
}
