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
            ensure_installed = { "clangd" },
        },
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            vim.diagnostic.config({ virtual_text = true })

            vim.lsp.config("clangd", {
                cmd = { "clangd", "-j=4" },
            })
            vim.lsp.enable("clangd")
        end,
    },
}
