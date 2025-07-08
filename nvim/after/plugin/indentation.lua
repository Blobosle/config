require("nvim-treesitter.configs").setup {
    yati = {
        enable = true,
        disable = { "python" },

        default_lazy = true,

       default_fallback = "auto"
    },
    indent = {
        enable = false
    }
}
