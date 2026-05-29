-- Split screen remap
local function save_terminal_views()
    local views = {}

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)

            if vim.bo[buf].buftype == "terminal" then
                vim.api.nvim_win_call(win, function()
                    views[#views + 1] = {
                        win = win,
                        buf = buf,
                        view = vim.fn.winsaveview(),
                    }
                end)
            end
        end
    end

    return views
end

local function restore_terminal_views(views)
    for _, item in ipairs(views) do
        if vim.api.nvim_win_is_valid(item.win) and vim.api.nvim_win_get_buf(item.win) == item.buf then
            vim.api.nvim_win_call(item.win, function()
                pcall(vim.fn.winrestview, item.view)
            end)
        end
    end
end

local function vsplit_preserving_terminal_views()
    local views = save_terminal_views()

    vim.cmd("vsplit")
    vim.schedule(function()
        restore_terminal_views(views)
    end)
end

vim.keymap.set('n', 'S', vsplit_preserving_terminal_views, { noremap = true, silent = true })
vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(ev)
        vim.keymap.set('n', 'S', vsplit_preserving_terminal_views, {
            buffer = ev.buf,
            noremap = true,
            silent = true,
        })
        vim.keymap.set('n', '<leader>g', '<Nop>', {
            buffer = ev.buf,
            noremap = true,
            silent = true,
        })
    end,
})

-- Floating preview for LSP errors
vim.keymap.set("n", "<leader>r", function()
  vim.schedule(function()
    local d = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
    if #d == 0 then
      print("No diagnostics on this line")
      return
    end

    local lines = {}
    for _, x in ipairs(d) do
      table.insert(lines, x.message)
    end

    vim.lsp.util.open_floating_preview(lines, "plaintext", {
      border = "rounded",
      focusable = true,
      close_events = {},
    })
  end)
end, { desc = "Show line diagnostics" })

-- Copy-paste functionality
local mark_oscyank = '<Cmd>lua vim.g.user_oscyank_pending = true<CR>'
vim.keymap.set('n', '<C-c>', mark_oscyank .. '<Plug>OSCYankOperator', { remap = true, silent = true })
vim.keymap.set('v', '<C-c>', mark_oscyank .. '<Plug>OSCYankVisual', { remap = true, silent = true })

-- Cycling between numerous tabs
vim.api.nvim_set_keymap('n', 'A', ':tabnext<CR>', { noremap = true, silent = true })

local function shift_tab_indent_blank_line()
  local lnum = vim.fn.line(".")
  local width = vim.fn.cindent(lnum)

  if width < 0 then
    width = 0
  end

  local indent = string.rep(" ", width)
  vim.api.nvim_set_current_line(indent)
  vim.api.nvim_win_set_cursor(0, { lnum, width })
end

vim.api.nvim_create_user_command("UserShiftTabIndentBlankLine", shift_tab_indent_blank_line, {})

-- Shift tab
vim.keymap.set("i", "<S-Tab>", function()
  local line = vim.api.nvim_get_current_line()
  if line:match("^%s*$") then
    return vim.api.nvim_replace_termcodes("<C-o>:<C-u>UserShiftTabIndentBlankLine<CR>", true, false, true)
  end

  return vim.api.nvim_replace_termcodes("<Esc>==gi", true, false, true)
end, { expr = true, noremap = true, silent = true })

-- C style make vim command setup
vim.opt.makeprg = "gcc %:S && ./a.out"

-- Commands to shorten Vim editor writing and exits
vim.api.nvim_set_keymap('n', 'ZC', ':q<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'ZX', ':q!<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'ZA', '<Cmd>silent write<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'Ñ', '<Cmd>silent write<CR>', { noremap = true, silent = true })
vim.api.nvim_create_user_command("W", "w", {})

-- Visual block shifting with indentation
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Remap for auto suggestions (dropdown autocompletion)
vim.api.nvim_set_keymap('i', 'S>', '<C-n>', { noremap = true, silent = true })

-- Remap for s acting as an entry to insert mode
vim.api.nvim_set_keymap('n', 'x', 's', { noremap = true })

-- Remap for s acting as an entry to insert mode
vim.api.nvim_set_keymap('n', 's', 'i', { noremap = true })

-- Remap for using option delete for deleting words
vim.api.nvim_set_keymap('i', '<M-BS>', '<C-w>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<M-BS>', '<C-w>', { noremap = true, silent = true })

-- Remap for clearing search highlighting
vim.keymap.set('n', '<leader><space>', ':nohlsearch<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<esc>', ':nohlsearch<CR>', { noremap = true, silent = true })

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

-- Terminal remappings for facilitated use
vim.api.nvim_set_keymap('t', '<Esc>', '<C-\\><C-N>', { noremap = true, silent = true })

-- Visual line movement
vim.keymap.set("n", "<Down>", "gj", { noremap = true })
vim.keymap.set("n", "<Up>", "gk", { noremap = true })

-- Visual line movement for insert mode
vim.keymap.set("i", "<Down>", [[<C-o>gj]])
vim.keymap.set("i", "<Up>", [[<C-o>gk]])

-- Closing memento with esc
vim.api.nvim_create_autocmd("FileType", {
    pattern = "memento",
    callback = function(ev)
        vim.keymap.set("n", "<Esc>", function()
            require("memento").toggle()
        end, { buffer = ev.buf, silent = true, desc = "Close Memento" })
    end,
})

-- Unmapping C-e
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    pcall(vim.keymap.del, "n", "<C-e>")
    vim.keymap.set("n", "<C-e>", function()
      if _G.harpoon_menu_from_root then
        return _G.harpoon_menu_from_root()
      end

      local prev = vim.fn.getcwd()
      pcall(vim.cmd, "cd " .. vim.fn.fnameescape(_G.ROOT_CWD or prev))
      require("harpoon.ui").toggle_quick_menu()
      pcall(vim.cmd, "cd " .. vim.fn.fnameescape(prev))
    end, { desc = "Harpoon: quick menu", noremap = true, silent = true })
  end,
})

-- Custom escape for nested neovim instanc
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', {noremap = true, silent = true})
