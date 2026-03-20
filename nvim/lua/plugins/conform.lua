return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        opts = {
            formatters_by_ft = {
                swift = { "swiftformat" },
            },
            format_on_save = function(bufnr)
                local ft = vim.bo[bufnr].filetype
                local allowed = {
                    javascript = true,
                    javascriptreact = true, -- jsx
                    typescript = true,
                    typescriptreact = true, -- tsx
                    swift = true,
                }

                if allowed[ft] then
                    return {
                        timeout_ms = 1000,
                        lsp_format = "fallback",
                    }
                end

                return nil
            end,
        },
    },
}
