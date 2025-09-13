-- Remove all trailing whitespaces except in specific file types
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",   
    callback = function()
        local filetype = vim.bo.filetype
        if filetype ~= "txt" then
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            vim.cmd([[%s/\s\+$//e]])
            vim.api.nvim_win_set_cursor(0, cursor_pos)
        end
    end,
})

-- Sets tabs instead of spaces for Makefiles
vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab  = false
    vim.opt_local.tabstop   = 8
    vim.opt_local.shiftwidth= 8
    vim.opt_local.softtabstop = 8
  end,
})

-- Sets space indentation to 2 for specific file types
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "c" },
    callback = function()
        local fname = vim.fn.expand("%:p")
        local pd1 = vim.fn.expand("~/Purdue/")
        local pd2 = vim.fn.expand("~/Desktop/Purdue/")

        if fname:sub(1, #pd1) ~= pd1 and fname:sub(1, #pd2) ~= pd2 then
            return
        end

        vim.opt_local.tabstop    = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab  = true
    end,
})


