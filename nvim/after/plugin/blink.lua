require('blink.cmp').setup({
    keymap = {
        preset = 'default',       -- “default” mappings (C-y to accept, etc.)
    },

    completion = {
        documentation = {
            auto_show = false,      -- only show docs when manually triggered
        },
    },

    sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
    },

    fuzzy = {
        implementation = 'prefer_rust_with_warning',
    },
})
