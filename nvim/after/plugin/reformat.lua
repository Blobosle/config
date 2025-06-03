-- Remove all trailing whitespaces except in specific file types
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function()
        local filetype = vim.bo.filetype
        if filetype ~= "txt" then
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            vim.cmd([[%s/\s\+$//e]])
            vim.api.nvim_win_set_cursor(0, cursor_pos)
        end
    end,
})

-- Sets tabs instead of spaces for Makefiles
vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab  = false
    vim.opt_local.tabstop   = 8
    vim.opt_local.shiftwidth= 8
    vim.opt_local.softtabstop = 8
  end,
})

-- Sets space indentation to 2 for specific file types
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "c" },
    callback = function()
        local fname = vim.fn.expand("%:p")
        local pd1 = vim.fn.expand("~/Purdue/")
        local pd2 = vim.fn.expand("~/Desktop/Purdue/")

        if fname:sub(1, #pd1) ~= pd1 and fname:sub(1, #pd2) ~= pd2 then
            return
        end

        vim.opt_local.tabstop    = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab  = true
    end,
})


-- Adds comments on abbreviation
vim.api.nvim_create_autocmd("FileType", {
  pattern = {"c", "cpp"},
  callback = function()
    vim.cmd('inoreabbrev com /**/<Esc>hi')
  end,
})

-- Enables #if 0 and #endif shortcut when editing C files
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'c',
  callback = function()

    -- Command for inserting #if 0 and #endif
    vim.api.nvim_buf_create_user_command(0, 'InsertIf0', function(opts)
      local buf = vim.api.nvim_get_current_buf()
      local s_line = opts.line1
      local e_line = opts.line2

      vim.api.nvim_buf_set_lines(buf, e_line, e_line, false, {'#endif'})
      vim.api.nvim_buf_set_lines(buf, s_line - 1, s_line - 1, false, {'#if 0'})
    end, { range = true })

    -- Command for removing #if 0 and #endif
    vim.api.nvim_buf_create_user_command(0, 'RemoveIf0', function(opts)
      local buf = vim.api.nvim_get_current_buf()
      local s_line = opts.line1 - 1
      local e_line = opts.line2 - 1
      local lines = vim.api.nvim_buf_get_lines(buf, s_line, e_line + 1, false)
      local indices_to_remove = {}

      for idx, line in ipairs(lines) do
        if line:match('^%s*#if%s+0') or line:match('^%s*#endif') then
          table.insert(indices_to_remove, idx)
        end
      end

      for i = #indices_to_remove, 1, -1 do
        local idx = indices_to_remove[i]
        vim.api.nvim_buf_set_lines(buf, s_line + idx - 1, s_line + idx, false, {})
      end
    end, { range = true })

    -- Keymap for inserting block comments to gbi (buffer-local)
    vim.api.nvim_buf_set_keymap(0, 'x', 'gbi', ':InsertIf0<CR>', { noremap = true, silent = true })

    -- Keymap for removing block comments to gbu (buffer-local)
    vim.api.nvim_buf_set_keymap(0, 'x', 'gbu', ':RemoveIf0<CR>', { noremap = true, silent = true })
  end
})

-- Function to modify 'w' behavior in normal mode
function CustomForwardWord()
    local original_isk = vim.opt.iskeyword:get()
    vim.opt.iskeyword:remove('_')
    vim.cmd('normal! w')
    vim.opt.iskeyword = original_isk
end

-- Remap 'w' in normal mode
vim.api.nvim_set_keymap('n', 'w', ':lua CustomForwardWord()<CR>', { noremap = true, silent = true })

-- Opens the memento
vim.api.nvim_set_keymap('n', '<C-p>', "<cmd>lua require('memento').toggle()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'M', "<cmd>lua require('memento').clear_history()<CR>", { noremap = true, silent = true })
vim.g.memento_history = 50

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
    pos[1] = pos[1] - 1
    pos[2] = #vim.fn.getline(pos[1] + 1)
  end

  vim.api.nvim_win_set_cursor(win, { pos[1] + 1, pos[2] })
end

-- Remap for cursor jumping paste function
vim.keymap.set('n', 'p', function() put_and_land('p') end, { desc = 'put & land at end' })
