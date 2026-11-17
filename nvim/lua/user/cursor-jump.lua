-- Function to modify 'w' behavior in normal mode
function CustomForwardWord()
    local original_isk = vim.opt.iskeyword:get()
    vim.opt.iskeyword:remove('_')
    vim.cmd('normal! w')
    vim.opt.iskeyword = original_isk
end

-- Remap 'w' in normal mode
vim.api.nvim_set_keymap('n', 'w', ':lua CustomForwardWord()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', 'l', function()
  return vim.v.count > 0 and 'Gzz' or 'l'
end, { expr = true, desc = 'Jump to line and center with a count' })

-- Yank cursor set
vim.keymap.set('x', 'y', 'ygv<Esc>', { noremap = true, silent = true })

-- Function to move cursor to the end of the pasted code block
local function put_and_land(where)
  local win  = 0
  local buf  = 0
  local rtype = vim.fn.getregtype('"'):sub(1,1)

  vim.cmd('keepjumps normal! ' .. where)

  local pos = { unpack(vim.api.nvim_buf_get_mark(buf, ']')) }

  if rtype == 'V' then
    pos[2] = #vim.fn.getline(pos[1])
  end

  vim.api.nvim_win_set_cursor(win, pos)
end

-- Remap for cursor jumping paste function
vim.keymap.set('n', 'p', function() put_and_land('p') end, { desc = 'put & land at end' })
