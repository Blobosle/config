return {
    {
        "ThePrimeagen/harpoon",
        commit = "ccae1b9",
        dependencies = { "nvim-lua/plenary.nvim" },

        config = function()
            _G.ROOT_CWD = _G.ROOT_CWD or vim.fn.getcwd()

            local function with_root(fn)
                local prev = vim.fn.getcwd()
                pcall(vim.cmd, "cd " .. vim.fn.fnameescape(_G.ROOT_CWD))

                local ok, err = pcall(fn)
                if not ok then
                    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(prev))
                    error(err)
                end

                return prev
            end

            local function cd_to_current_file_dir()
                local name = vim.api.nvim_buf_get_name(0)
                if name == "" or vim.fn.isdirectory(name) == 1 then return end
                local dir = vim.fn.fnamemodify(name, ":p:h")
                pcall(vim.cmd, "cd " .. vim.fn.fnameescape(dir))
            end

            _G.harpoon_add_from_root = function()
                local prev = with_root(function()
                    require("harpoon.mark").add_file()
                end)
                pcall(vim.cmd, "cd " .. vim.fn.fnameescape(prev))
            end

            _G.harpoon_nav_from_root = function(i)
                with_root(function()
                    require("harpoon.ui").nav_file(i)
                end)
                -- important: wait until after buffer switch completes
                vim.schedule(function()
                    cd_to_current_file_dir()
                end)
            end
        end,

        keys = {
            { "<leader>a", function() _G.harpoon_add_from_root() end, desc = "Harpoon: add file (from root)" },
            { "<C-e>", function() require("harpoon.ui").toggle_quick_menu() end, desc = "Harpoon: quick menu" },
            { "<C-z>", function() _G.harpoon_nav_from_root(1) end, desc = "Harpoon: to file 1 (from root)" },
            { "<C-x>", function() _G.harpoon_nav_from_root(2) end, desc = "Harpoon: to file 2 (from root)" },
            { "<C-s>", function() _G.harpoon_nav_from_root(3) end, desc = "Harpoon: to file 3 (from root)" },
            { "<C-a>", function() _G.harpoon_nav_from_root(4) end, desc = "Harpoon: to file 4 (from root)" },
        },
    },
}
