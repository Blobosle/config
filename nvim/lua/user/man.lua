vim.api.nvim_create_user_command('Vman', function(opts)
    vim.cmd('vertical Man ' .. opts.args)
end, { nargs = '+' })

