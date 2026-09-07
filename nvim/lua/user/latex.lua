local function show_latex_message(message, level)
  if _G.UserShowTopMessage then
    _G.UserShowTopMessage(message)
  else
    vim.notify(message, level)
  end
end

local function open_pdf_for_tex(tex_path)
    local pdf_path = vim.fn.fnamemodify(tex_path, ':p:r') .. '.pdf'
    vim.fn.jobstart({ 'open', pdf_path }, { detach = true })
end

local function has_latex_makefile(file_dir)
  for _, name in ipairs({ 'GNUmakefile', 'Makefile', 'makefile' }) do
    local path = file_dir .. '/' .. name
    if vim.fn.filereadable(path) == 1 then
      local contents = table.concat(vim.fn.readfile(path), '\n')
      if contents:find('latexmk', 1, true) then
        return true
      end
    end
  end

  return false
end

-- Compile a tex file with latexmk without blocking Neovim
local function compile_latex_file(tex_path)
  tex_path = vim.fn.fnamemodify(tex_path or '', ':p')

  if tex_path == '' or vim.fn.fnamemodify(tex_path, ':e') ~= 'tex' then
    local message = 'Skipping LaTeX compilation.'
    show_latex_message(message, vim.log.levels.WARN)
    return
  end

  local file_dir = vim.fn.fnamemodify(tex_path, ':h')
  local tex_file = vim.fn.fnamemodify(tex_path, ':t')
  local pdf_file = vim.fn.fnamemodify(tex_path, ':t:r') .. '.pdf'
  local command

  vim.fn.mkdir(file_dir .. '/.latex', 'p')

  if has_latex_makefile(file_dir) then
    command = { 'make', '--no-print-directory' }

    -- An existing root PDF built with a different output directory can make
    -- make skip the first .latex build. Force only that one-time migration.
    local root_pdf = file_dir .. '/' .. pdf_file
    local latex_pdf = file_dir .. '/.latex/' .. pdf_file
    if vim.fn.filereadable(root_pdf) == 1 and vim.fn.filereadable(latex_pdf) ~= 1 then
      table.insert(command, '-B')
    end

    table.insert(command, 'BUILDDIR=.latex')
    table.insert(command, pdf_file)
  else
    command = {
      'latexmk',
      '-pdf',
      '-interaction=nonstopmode',
      '-silent',
      '-auxdir=.latex',
      tex_file,
    }
  end

  vim.fn.jobstart(command, {
    cwd = file_dir,
    on_exit = function(_, code, _)
      if code == 0 then
        vim.notify('LaTeX build finished', vim.log.levels.INFO)
        vim.schedule(function()
          open_pdf_for_tex(tex_path)
        end)
      else
        vim.notify('LaTeX build failed', vim.log.levels.ERROR)
      end
    end,
  })
end

_G.UserCompileLatexFile = compile_latex_file

-- Compile the current buffer with pdflatex (×3) without blocking Neovim
vim.api.nvim_create_user_command('Latex', function()
  compile_latex_file(vim.fn.expand('%:p'))
end, {})

-- Keep a per‑session record of PDFs we’ve launched.
local opened_pdfs = {}

-- Open the resulting PDF in Preview, but only once per session
vim.api.nvim_create_user_command('OpenPDF', function()
    open_pdf_for_tex(vim.fn.expand('%:p'))
end, {})

-- Convenience alias
vim.api.nvim_create_user_command('LTX', 'Latex', {})
vim.api.nvim_set_keymap('n', 'L', ':Latex<CR>', { noremap = true, silent = true })
