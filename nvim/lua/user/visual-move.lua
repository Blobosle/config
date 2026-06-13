-- Visual block shifting with indentation
local function move_visual(direction)
  if vim.fn.mode() ~= "\22" then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local anchor = vim.fn.getpos("v")
    local first = math.min(cursor[1], anchor[2])
    local last = math.max(cursor[1], anchor[2])

    if (direction > 0 and last == vim.fn.line("$")) or (direction < 0 and first == 1) then
      return
    end

    vim.cmd("normal! \27")
    local ok = pcall(vim.cmd, direction > 0 and "'<,'>move '>+1" or "'<,'>move '<-2")
    if not ok then
      return
    end

    vim.cmd("normal! gv=gv")
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local anchor = vim.fn.getpos("v")
  local first = math.min(cursor[1], anchor[2])
  local last = math.max(cursor[1], anchor[2])

  if (direction > 0 and last == vim.fn.line("$")) or (direction < 0 and first == 1) then
    return
  end

  vim.cmd("normal! \27")

  local selected = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  if direction > 0 then
    local below = vim.api.nvim_buf_get_lines(0, last, last + 1, false)
    vim.list_extend(below, selected)
    vim.api.nvim_buf_set_lines(0, first - 1, last + 1, false, below)
  else
    local above = vim.api.nvim_buf_get_lines(0, first - 2, first - 1, false)
    vim.list_extend(selected, above)
    vim.api.nvim_buf_set_lines(0, first - 2, last, false, selected)
  end

  vim.api.nvim_win_set_cursor(0, { anchor[2] + direction, anchor[3] - 1 })
  vim.cmd("normal! \22")
  vim.api.nvim_win_set_cursor(0, { cursor[1] + direction, cursor[2] })
end

vim.keymap.set("v", "J", function()
  move_visual(1)
end)
vim.keymap.set("v", "K", function()
  move_visual(-1)
end)
