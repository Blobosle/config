-- Opening shell whole screen
_G.cd_and_open_term = function()
    local original_dir = vim.fn.getcwd()
    vim.cmd('cd %:p:h')
    vim.cmd('term')

    vim.cmd('autocmd TermClose * ++once lua vim.cmd("cd ' .. original_dir .. '")')
end

-- Opening shell split screen
_G.cd_and_open_term_mod = function()
    local original_win = vim.api.nvim_get_current_win()
    local original_dir = vim.fn.getcwd()

    vim.cmd('lcd %:p:h')
    vim.cmd('vsplit')
    vim.cmd('term')

    local new_win = vim.api.nvim_get_current_win()
    local term_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_current_win(original_win)
    vim.cmd('lcd ' .. original_dir)
    vim.api.nvim_set_current_win(new_win)

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = term_bufnr,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(new_win) then
                vim.api.nvim_set_current_win(new_win)
            end
        end,
    })
end

vim.api.nvim_set_keymap('n', 'Q', ':lua cd_and_open_term()<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<leader>q', ':lua _G.cd_and_open_term_mod()<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('t', '<C-q>', [[<C-\><C-n>i exit<CR>]], { noremap = true, silent = true })

-- Commands for cycling split selection with the new split screen shell instance
vim.api.nvim_set_keymap('n', '<S-CR>', '<C-w>w', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<S-CR>', '<C-\\><C-n><C-w>w', { noremap = true, silent = true })

-- Skips unnecesary terminal instance closing sequence
vim.api.nvim_create_autocmd("TermClose", {
    pattern = "*",
    callback = function(args)
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
                local success, err = pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
                if not success then
                    vim.notify("Error deleting buffer: " .. err, vim.log.levels.ERROR)
                end
            end
        end)
    end,
})
