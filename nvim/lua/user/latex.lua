-- Compile the current buffer with pdflatex (×3) without blocking Neovim
vim.api.nvim_create_user_command('Latex', function()
    local file_dir  = vim.fn.expand('%:p:h')
    local file_name = vim.fn.expand('%:t:r')
    local tex_file  = file_name .. '.tex'
    local pdf_file  = file_name .. '.pdf'

    local cmd = table.concat({
        'cd', vim.fn.shellescape(file_dir), '&&',
        'rm -f', vim.fn.shellescape(pdf_file), '&&',
        ('for i in 1 2 3; do pdflatex -interaction=batchmode %s; done;')
            :format(vim.fn.shellescape(tex_file)),
        'rm -f', vim.fn.shellescape(file_name .. '.aux'),
        vim.fn.shellescape(file_name .. '.log')
    }, ' ')

    vim.fn.jobstart({ 'sh', '-c', cmd }, {
        -- no on_stdout / on_stderr → no log spam
        on_exit = function(_, code, _)
            if code == 0 then
                vim.notify('pdflatex finished successfully', vim.log.levels.INFO)
                vim.schedule(function() vim.cmd('OpenPDF') end)
            end
        end,
    })
end, {})

-- Keep a per‑session record of PDFs we’ve launched.
local opened_pdfs = {}

-- Open the resulting PDF in Preview, but only once per session
vim.api.nvim_create_user_command('OpenPDF', function()
    local pdf_path = vim.fn.expand('%:p:r') .. '.pdf'   -- absolute path
    vim.fn.jobstart({ 'open', pdf_path }, { detach = true })
end, {})

-- Convenience alias
vim.api.nvim_create_user_command('LTX', 'Latex', {})
vim.api.nvim_set_keymap('n', 'L', ':Latex<CR>', { noremap = true, silent = true })
