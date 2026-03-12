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
            ensure_installed = { "clangd", "ts_ls", "tailwindcss", "cmake", "protols" },
        },
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            vim.diagnostic.config({ virtual_text = true })

            vim.lsp.enable("clangd")
            vim.lsp.enable("ts_ls")
            vim.lsp.enable("tailwindcss")
            vim.lsp.enable("cmake")
            vim.lsp.enable("protols")
        end,
    },
}
