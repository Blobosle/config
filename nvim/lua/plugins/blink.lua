return {
    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        main = "blink.cmp",
        enabled = true,
        opts = {
            keymap = {
                preset = "default",
                ["<S-CR>"] = { "select_and_accept" },
            },
            appearance = {
                nerd_font_variant = "mono",
            },
            completion = {
                documentation = {
                    auto_show = false,
                },
                menu = {
                    auto_show = function(ctx, items) return vim.bo.filetype == 'c' end,
                },
            },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },
            fuzzy = {
                implementation = "lua",
            },
        },
    },
}
