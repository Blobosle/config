vim.opt.spellsuggest = "best,9"

local function spell_target()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local original_pos = vim.api.nvim_win_get_cursor(win)
  local bad = vim.fn.spellbadword()
  local word = bad[1] or ""

  if word ~= "" then
    local pos = vim.api.nvim_win_get_cursor(win)
    return {
      win = win,
      buf = buf,
      word = word,
      kind = bad[2],
      lnum = pos[1],
      start_col = pos[2],
      end_col = pos[2] + #word,
    }
  end

  vim.api.nvim_win_set_cursor(win, original_pos)

  local line = vim.api.nvim_get_current_line()
  local col = original_pos[2] + 1
  local start_col = col
  while start_col > 1 and line:sub(start_col - 1, start_col - 1):match("[%w_]") do
    start_col = start_col - 1
  end

  local end_col = col
  while end_col <= #line and line:sub(end_col, end_col):match("[%w_]") do
    end_col = end_col + 1
  end

  word = line:sub(start_col, end_col - 1)
  if word == "" then
    return nil
  end

  return {
    win = win,
    buf = buf,
    word = word,
    kind = "",
    lnum = original_pos[1],
    start_col = start_col - 1,
    end_col = end_col - 1,
  }
end

local function apply_spell_suggestion(target, suggestion)
  if not suggestion or not vim.api.nvim_buf_is_valid(target.buf) then
    return
  end

  vim.api.nvim_buf_set_text(
    target.buf,
    target.lnum - 1,
    target.start_col,
    target.lnum - 1,
    target.end_col,
    { suggestion }
  )

  if vim.api.nvim_win_is_valid(target.win) then
    vim.api.nvim_win_set_cursor(target.win, { target.lnum, target.start_col + #suggestion })
  end
end

local function spell_suggest_with_border()
  local target = spell_target()
  if not target then
    vim.notify("No word under or after the cursor", vim.log.levels.INFO)
    return
  end

  local suggestions = vim.fn.spellsuggest(target.word, 9, target.kind == "caps")
  if #suggestions == 0 then
    vim.notify("No spelling suggestions", vim.log.levels.INFO)
    return
  end

  if vim.v.count > 0 then
    apply_spell_suggestion(target, suggestions[vim.v.count])
    return
  end

  local lines = { ('Change "%s" to:'):format(target.word) }
  for index, suggestion in ipairs(suggestions) do
    lines[#lines + 1] = ("%d %s"):format(index, suggestion)
  end

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, vim.o.columns - 4)

  local height = #lines
  local row = math.max(vim.o.lines - height - 4, 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

  local suggest_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(suggest_buf, 0, -1, false, lines)
  vim.bo[suggest_buf].modifiable = false
  vim.bo[suggest_buf].bufhidden = "wipe"

  local suggest_win = vim.api.nvim_open_win(suggest_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "single",
    style = "minimal",
    zindex = 70,
  })
  vim.wo[suggest_win].winhighlight = "Normal:Normal,FloatBorder:StatusLine"
  vim.api.nvim_win_set_cursor(suggest_win, { math.min(2, height), 0 })

  local function close()
    if vim.api.nvim_win_is_valid(suggest_win) then
      vim.api.nvim_win_close(suggest_win, true)
    end
  end

  local function select(index)
    close()
    apply_spell_suggestion(target, suggestions[index])
  end

  for index = 1, #suggestions do
    vim.keymap.set("n", tostring(index), function()
      if vim.api.nvim_win_is_valid(suggest_win) then
        vim.api.nvim_win_set_cursor(suggest_win, { index + 1, 0 })
      end
    end, { buffer = suggest_buf, nowait = true, silent = true })
  end

  vim.keymap.set("n", "<CR>", function()
    local row_num = vim.api.nvim_win_get_cursor(suggest_win)[1]
    select(row_num - 1)
  end, { buffer = suggest_buf, silent = true })
  vim.keymap.set("n", "q", close, { buffer = suggest_buf, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = suggest_buf, silent = true })
end

vim.keymap.set("n", "z=", spell_suggest_with_border, { noremap = true, desc = "Spell suggestions" })
