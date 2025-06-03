-- Close memento window using Esc key
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'memento',
  callback = function()
    vim.keymap.set('n', '<Esc>', require('memento').toggle, {
      buffer = true,
      silent = true,
      desc   = 'Close Memento',
    })
  end,
})
