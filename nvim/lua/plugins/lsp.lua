return {
    {
        "mason-org/mason.nvim",
        build = ":MasonUpdate",
        opts = {},
    },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            "mason-org/mason.nvim",
            "neovim/nvim-lspconfig",
        },
        opts = {
            automatic_enable = false,
            ensure_installed = { "clangd", "ts_ls", "tailwindcss", "cmake", "protols"},
        },
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            vim.diagnostic.config({ virtual_text = true })

            local lsp = require("lspconfig")
            lsp.clangd.setup({})
            lsp.ts_ls.setup({})
            lsp.tailwindcss.setup({})
            lsp.cmake.setup({})
            lsp.protols.setup({})
        end,
    },
}
