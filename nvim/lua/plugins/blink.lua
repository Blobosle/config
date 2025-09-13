return {
    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        main = "blink.cmp",
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
