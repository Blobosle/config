-- -- Function that creates a pdf using pdflatex 3 times
-- vim.api.nvim_create_user_command('Latex', function()
--     local file_dir = vim.fn.expand('%:p:h')
--     vim.cmd('cd ' .. vim.fn.fnameescape(file_dir))
--
--     local file_name = vim.fn.expand('%:t:r')
--     local tex_file = file_name .. '.tex'
--     local pdf_file = file_name .. '.pdf'
--
--     vim.fn.system({'rm', '-f', pdf_file})
--
--     for _ = 1, 3 do
--         vim.fn.system({'pdflatex', '-interaction=batchmode', tex_file})
--     end
--
--     vim.fn.system({'rm', '-f', file_name .. '.aux', file_name .. '.log'})
--
--     vim.cmd('OpenPDF')
--
--     vim.cmd('cd -')
-- end, {})
--
-- -- Runs the shell open command on the corresponding .tex file
-- vim.api.nvim_create_user_command('OpenPDF', function()
--     local pdf_file = vim.fn.expand('%:t:r') .. '.pdf'
--
--     vim.fn.jobstart({'open', pdf_file}, {detach = true})
-- end, {})
--
-- -- Shortcut for runing mintex
-- vim.api.nvim_create_user_command('LTX', 'Latex', {})



-- ###################################

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

