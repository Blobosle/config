return {
    {
        "github/copilot.vim",
        event = "VeryLazy",
        init = function()
            vim.g.copilot_no_tab_map = true
        end,
        config = function()
            vim.cmd("silent! Copilot disable")
        end,
        keys = {
            {
                "<S-Tab>",
                'copilot#Accept("<CR>")',
                mode = "i",
                expr = true,
                silent = true,
                replace_keycodes = false,
                desc = "Copilot: accept suggestion",
            },
            { "<leader>ce", "<Cmd>Copilot enable<CR>",  desc = "Copilot: enable" },
            { "<leader>cd", "<Cmd>Copilot disable<CR>", desc = "Copilot: disable" },
            {
                "<leader>ct",
                function()
                    -- buffer-local toggle
                    if vim.b.copilot_enabled == false or vim.b.copilot_enabled == 0 then
                        vim.b.copilot_enabled = true
                        print("Copilot: enabled (buffer)")
                    else
                        vim.b.copilot_enabled = false
                        print("Copilot: disabled (buffer)")
                    end
                end,
                desc = "Copilot: toggle (buffer)",
            },
        },
    },
}
