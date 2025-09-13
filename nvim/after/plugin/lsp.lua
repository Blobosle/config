require("mason").setup()

require("mason-lspconfig").setup({
  automatic_enable = false,
  ensure_installed = { "clangd", "texlab", "ts_ls", "neocmake" },
})

local lsp = require("lspconfig")
lsp.clangd.setup({})
lsp.ts_ls.setup({})
lsp.texlab.setup({})
lsp.neocmake.setup({})

vim.diagnostic.config({
  virtual_text = true,
})
