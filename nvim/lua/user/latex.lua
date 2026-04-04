-- Compile the current buffer with pdflatex (×3) without blocking Neovim
vim.api.nvim_create_user_command('Latex', function()
  if vim.fn.expand('%:e') ~= 'tex' then
    vim.notify('Skipping LaTeX compilation.', vim.log.levels.WARN)
    return
  end

  local file_dir = vim.fn.expand('%:p:h')
  local tex_file = vim.fn.expand('%:t')
  local pdf_path = file_dir .. '/.latex/' .. vim.fn.expand('%:t:r') .. '.pdf'

  vim.fn.mkdir(file_dir .. '/.latex', 'p')

  vim.fn.jobstart({
    'latexmk',
    '-pdf',
    '-interaction=nonstopmode',
    '-silent',
    '-auxdir=.latex',
    tex_file,
  }, {
    cwd = file_dir,
    on_exit = function(_, code, _)
      if code == 0 then
        vim.notify('LaTeX build finished', vim.log.levels.INFO)
        vim.schedule(function()
          vim.cmd('OpenPDF')
        end)
      else
        vim.notify('LaTeX build failed', vim.log.levels.ERROR)
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
