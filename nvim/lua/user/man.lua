vim.api.nvim_create_user_command('Vman', function(opts)
    vim.cmd('vertical Man ' .. opts.args)
end, { nargs = '+' })

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'man',
    callback = function(ev)
        vim.keymap.set('n', '<2-LeftMouse>', '<Cmd>silent! Man<CR>', {
            buffer = ev.buf,
            silent = true,
        })
    end,
})

