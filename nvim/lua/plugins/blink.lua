return {
    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        main = "blink.cmp",
        enabled = true,
        opts = {
            cmdline = { enabled = false },
            keymap = {
                preset = "default",
                ["<S-CR>"] = { "select_and_accept" },
            },
            appearance = { nerd_font_variant = "mono" },
            completion = { documentation = { auto_show = false } },
            sources = { default = { "lsp", "path", "snippets", "buffer" } },
            fuzzy = { implementation = "lua" },
        },
    },
}

