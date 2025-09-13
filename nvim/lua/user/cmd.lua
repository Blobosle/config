vim.keymap.set('n', ';', ':', { noremap = true, silent = true })
vim.keymap.set('n', ':', 'q:i', { noremap = true, silent = true })

vim.keymap.set('x', ':', function()
    vim.api.nvim_feedkeys("q:$a", 'n', false)
end, { noremap = true, silent = true })

local grp = vim.api.nvim_create_augroup('CmdwinEscQuit', { clear = true })
vim.api.nvim_create_autocmd('CmdwinEnter', {
    group = grp,
    callback = function()
        vim.keymap.set('n', '<Esc>', '<Cmd>q<CR>', { buffer = true, silent = true, desc = 'Close cmdwin' })
    end,
})

