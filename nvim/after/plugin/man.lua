-- Store the original colorscheme
local original_colorscheme = vim.g.colors_name

-- Changes the colorscheme of Vim when reading man pages
vim.api.nvim_create_autocmd("FileType", {
    pattern = "man",
    callback = function()
        -- Save the current colorscheme if not already saved
        original_colorscheme = original_colorscheme or vim.g.colors_name
        vim.cmd("set background=dark")
        vim.cmd("colorscheme everforest")
        vim.opt.laststatus = 0
    end,
})

-- Restores the original colorscheme and status line when leaving man pages
vim.api.nvim_create_autocmd("BufLeave", {
    pattern = "man://*",
    callback = function()
        if original_colorscheme then
            vim.cmd("set background=light")
            vim.cmd("colorscheme " .. original_colorscheme)
        end
        vim.opt.laststatus = 2
    end,
})
