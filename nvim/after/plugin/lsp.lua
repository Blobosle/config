require("mason").setup()
require("mason-lspconfig").setup()

-- Setup the current and new language servers
require("mason-lspconfig").setup {
    ensure_installed = {"clangd", "texlab", "ts_ls"},
}

-- Required setup for C LSP (clangd)
require("lspconfig").clangd.setup {
    on_attach = on_attach
}

require'lspconfig'.ts_ls.setup{}

require'lspconfig'.texlab.setup{}
