vim.keymap.set({'v', 'n'}, ';', ':', { noremap = true })
vim.keymap.set('n', ':', 'q:i', { noremap = true, silent = true })

vim.keymap.set('x', ':', function()
    vim.api.nvim_feedkeys("q:$a", 'n', false)
end, { noremap = true, silent = true })

local grp = vim.api.nvim_create_augroup('CmdwinEscQuit', { clear = true })
vim.api.nvim_create_autocmd('CmdwinEnter', {
    group = grp,
    callback = function()
        vim.keymap.set('n', '<Esc>', '<Cmd>q<CR>', { buffer = true, silent = true, desc = 'Close cmdwin' })
    end,
})


-- SPLIT EXP
-- STREAMER ---------------------------------------------------------------
local function sh_stream_in_split(cmd, opts)
  opts = opts or {}
  local title  = opts.title or ("[shell] " .. cmd)
  local cwd    = opts.cwd
  local env    = opts.env
  local height = opts.height
  local follow_enabled = opts.follow ~= false
  local stdin_lines = opts.stdin_lines  -- <<— NEW: optional table of strings for stdin

  cmd = cmd:gsub("^%s*[!$]", "")

  vim.cmd("belowright new")
  if height and tonumber(height) then
    vim.cmd(("resize %d"):format(tonumber(height)))
  end

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = opts.filetype or "log"
  vim.api.nvim_buf_set_name(buf, title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$ " .. cmd, "" })

  local pending = {}
  local function add_lines(lines, prefix)
    if not lines or (#lines == 1 and lines[1] == "") then return end
    for _, l in ipairs(lines) do
      if l ~= "" then table.insert(pending, prefix and (prefix .. l) or l) end
    end
  end
  local function at_bottom_in_output_win()
    if not vim.api.nvim_win_is_valid(win) then return false end
    return vim.api.nvim_win_call(win, function()
      return vim.fn.line("w$") == vim.fn.line("$")
    end)
  end

  local timer = vim.loop.new_timer()
  local function flush()
    if #pending == 0 or not vim.api.nvim_buf_is_valid(buf) then return end
    local follow = follow_enabled and at_bottom_in_output_win()
    local n = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, n, n, false, pending)
    pending = {}
    if follow and vim.api.nvim_win_is_valid(win) then
      local last = vim.api.nvim_buf_line_count(buf)
      pcall(vim.api.nvim_win_set_cursor, win, { last, 0 })
    end
  end
  timer:start(50, 50, vim.schedule_wrap(flush))

  local aug = vim.api.nvim_create_augroup("ShStream_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = aug, buffer = buf,
    callback = function()
      if timer and not timer:is_closing() then timer:stop(); timer:close() end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = aug,
    callback = function(args)
      if tonumber(args.match) == win then
        if timer and not timer:is_closing() then timer:stop(); timer:close() end
      end
    end,
  })

  local shell = (vim.o.shell ~= "" and vim.o.shell) or os.getenv("SHELL") or "sh"
  local job_id = vim.fn.jobstart({ shell, "-lc", cmd }, {
    cwd = cwd,
    env = env,
    stdout_buffered = false,
    stderr_buffered = false,
    pty = false,             -- keep it non-terminal
    stdin = "pipe",          -- <<— ensure we can write to stdin
    on_stdout = vim.schedule_wrap(function(_, data) add_lines(data) end),
    on_stderr = vim.schedule_wrap(function(_, data) add_lines(data, "[stderr] ") end),
    on_exit   = vim.schedule_wrap(function(_, code)
      add_lines({ "", ("[exit %d]"):format(code) })
      flush()
      if timer and not timer:is_closing() then timer:stop(); timer:close() end
      if opts.readonly_on_exit and vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].modifiable = false
      end
    end),

  })

  if job_id <= 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "Failed to start job: " .. cmd,
      "TIP: try full path (e.g. ~/bin/mycmd) or check your shell rc.",
    })
    if timer and not timer:is_closing() then timer:stop(); timer:close() end
    return
  end

  -- <<— NEW: write stdin (if provided) and close it
  if stdin_lines and #stdin_lines > 0 then
    -- chansend accepts a list of lines; it will add newlines for you
    vim.fn.chansend(job_id, stdin_lines)
    vim.fn.chanclose(job_id, "stdin")
  end
end

-- USER COMMAND -----------------------------------------------------------
vim.api.nvim_create_user_command("Sh", function(args)
  sh_stream_in_split(args.args, { height = 20 })
end, { nargs = "+", complete = "shellcmd" })

-- :ShIn {cmd}   → stdin = whole buffer
vim.api.nvim_create_user_command("ShIn", function(args)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  sh_stream_in_split(args.args, { height = 20, stdin_lines = lines })
end, { nargs = "+", complete = "shellcmd" })

-- :[range]ShIn {cmd} → stdin = selected range (works with visual selection)
vim.api.nvim_create_user_command("ShR", function(args)
  local l1, l2 = args.line1, args.line2
  local lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
  sh_stream_in_split(args.args, { height = 20, stdin_lines = lines })
end, { nargs = "+", range = true, complete = "shellcmd" })

-- MAPPINGS FOR '$' -------------------------------------------------------

-- A) Regular ":" cmdline: at column 1, '$' -> "Sh "
vim.keymap.set("c", "$", function()
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdpos() == 1 then
    return "Sh "
  end
  return "$"
end, { expr = true })

-- B) q: cmdline-window: make '$' at col 1 expand to "Sh "
vim.api.nvim_create_autocmd("CmdwinEnter", {
  callback = function()
    local function at_col1() return vim.fn.col(".") == 1 end
    -- INSERT mode
    vim.keymap.set("i", "$", function()
      if at_col1() then return "Sh" end   -- NOTE THE SPACE
      return "$"
    end, { buffer = true, expr = true })
  end,
})

-- IMPORTANT: remove the cnoreabbrev; the mapping is enough and avoids conflicts.
-- (Delete your previous cnoreabbrev for '$' if it still exists.)
