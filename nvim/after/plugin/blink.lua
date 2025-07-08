require('blink.cmp').setup({
    keymap = {
        preset = 'default',       -- “default” mappings (C-y to accept, etc.)
        ['<S-CR>'] = { 'select_and_accept' },
    },
    appearance = {
        nerd_font_variant = 'mono', -- use “Nerd Font Mono” spacing
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
        implementation = 'lua',
    },
})
