return {
    {
        "navarasu/onedark.nvim",
        priority = 1000,
        config = function()
            vim.opt.termguicolors = true

            local white = "#FFFFFF"
            local dim   = "#2c313a" -- subtle bar shade; set to "NONE" for full transparency

            require("onedark").setup({
                -- Main options --
                style = "warm",
                transparent = true,       -- glassy background in Neovim
                term_colors = false,
                ending_tildes = false,
                cmp_itemkind_reverse = false,

                -- toggle theme style ---
                toggle_style_key = nil,
                toggle_style_list = { "dark", "darker", "cool", "deep", "warm", "warmer", "light" },

                -- Change code style ---
                code_style = {
                    comments = "italic",
                    keywords = "none",
                    functions = "none",
                    strings = "none",
                    variables = "none",
                },

                -- Lualine options --
                lualine = { transparent = true },

                -- Custom colors/highlights --
                -- colors = {},
                -- highlights = {
                --     netrwPlain = { fg = white },
                --     StatusLine = { fg = "#FFFFFF", bg = transparent },
                --     StatusLineNC = { fg = "#FFFFFF", bg = transparent },
                --     MsgArea = { fg = "#FFFFFF", bg = "NONE" },
                --     MsgSeparator= { fg = "#FFFFFF", bg = "NONE" },
                --     CmdwinNormal = { fg = white, bg = "NONE" },
                -- },

                -- Plugins Config --
                diagnostics = {
                    darker = true,
                    undercurl = true,
                    background = true,
                },
            })
            require("onedark").load()

            -- local grp = vim.api.nvim_create_augroup("CmdwinWhite", { clear = true })
            -- vim.api.nvim_create_autocmd("CmdwinEnter", {
            --     group = grp,
            --     callback = function()
            --         vim.api.nvim_set_hl(0, "CmdwinNormal", { fg = white, bg = "NONE" })
            --         vim.wo.winhl = table.concat({
            --             "Normal:CmdwinNormal",
            --             "NormalNC:CmdwinNormal",
            --             -- "LineNr:CmdwinNormal",
            --             "CursorLineNr:CmdwinNormal",
            --             "CursorLine:CmdwinNormal",
            --             -- "SignColumn:CmdwinNormal",
            --         }, ",")
            --     end,
            -- })
            -- vim.api.nvim_create_autocmd("CmdwinLeave", {
            --     group = grp,
            --     callback = function()
            --         vim.wo.winhl = ""
            --     end,
            -- })
        end,
    },
}


