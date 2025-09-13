return {
    {
        "gaborvecsei/memento.nvim",

        lazy = false,

        keys = {
            { "<C-p>", function() require("memento").toggle() end, desc = "Memento: Toggle picker", mode = "n", silent = true },
            { "M",     function() require("memento").clear_history() end, desc = "Memento: Clear history", mode = "n", silent = true },
        },

        init = function()
            vim.g.memento_history = 50
        end,
    },
}

