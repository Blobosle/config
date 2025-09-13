return {
    {
        "ThePrimeagen/harpoon",
        commit = "ccae1b9",
        dependencies = { "nvim-lua/plenary.nvim" },

        keys = {
            { "<leader>a", function() require("harpoon.mark").add_file() end, desc = "Harpoon: add file" },
            { "<C-e>", function() require("harpoon.ui").toggle_quick_menu() end, desc = "Harpoon: quick menu" },
            { "<C-z>", function() require("harpoon.ui").nav_file(1) end, desc = "Harpoon: to file 1" },
            { "<C-x>", function() require("harpoon.ui").nav_file(2) end, desc = "Harpoon: to file 2" },
            { "<C-s>", function() require("harpoon.ui").nav_file(3) end, desc = "Harpoon: to file 3" },
            { "<C-a>", function() require("harpoon.ui").nav_file(4) end, desc = "Harpoon: to file 4" },
        },
    },
}
