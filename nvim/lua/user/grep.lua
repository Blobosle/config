local function make_search_pattern(text, is_word)
    if is_word then
        return "\\<" .. vim.fn.escape(text, "\\^$.*~[]") .. "\\>"
    else
        return "\\V" .. vim.fn.escape(text, "\\")
    end
end

local function set_highlight_for(text, is_word)
    local pat = make_search_pattern(text, is_word)
    vim.fn.setreg("/", pat)
    vim.opt.hlsearch = true
end

local function jump_to_next_from_cursor()
    local items = vim.fn.getqflist()
    if #items == 0 then return end

    local curbuf = vim.api.nvim_get_current_buf()
    local pos = vim.api.nvim_win_get_cursor(0)
    local curline, curcol = pos[1], pos[2] + 1

    local idx, last_in_buf = nil, nil
    for i, it in ipairs(items) do
        if it.valid == 1 and it.bufnr == curbuf then
            last_in_buf = i
            local lnum = it.lnum or 0
            local col  = it.col or 0
            if lnum > curline or (lnum == curline and col >= curcol) then
                idx = i
                break
            end
        end
    end

    if not idx then
        if last_in_buf and last_in_buf < #items then
            idx = last_in_buf + 1
            while idx <= #items and items[idx].valid == 0 do
                idx = idx + 1
            end
            if idx > #items then idx = 1 end
        else
            idx = 1
        end
    end

    vim.cmd(("silent! cc %d | normal! zz"):format(idx))
end


local function get_visual_selection_safely()
    local save_reg = vim.fn.getreg('"')
    local save_type = vim.fn.getregtype('"')
    vim.cmd('silent! normal! "zy')
    local text = vim.fn.getreg('z') or ""
    vim.fn.setreg('"', save_reg, save_type)
    text = text:gsub("\r", "\n"):gsub("\n", " ")
    return text
end


local function add_file_separators_to_qf()
    local qf_items = vim.fn.getqflist()
    if #qf_items == 0 then return end

    local with_separators, prev_buf = {}, nil
    for _, it in ipairs(qf_items) do
        if prev_buf and it.bufnr ~= prev_buf then

            table.insert(with_separators, { text = "", valid = 0 })
        end
        table.insert(with_separators, it)
        prev_buf = it.bufnr
    end


    vim.fn.setqflist({}, 'r', { items = with_separators })
end


function _G.QfPrettyText(info)
    local ret = {}
    local items = info.items or {}

    for i = 1, #items do
        local e = items[i]


        if e and e.valid == 0 and (e.text == nil or e.text == "") then
            ret[i] = ""
        else

            local fname = ""
            if e and e.bufnr and e.bufnr > 0 then
                fname = vim.fn.bufname(e.bufnr)
            elseif e and e.filename then
                fname = e.filename
            end
            if fname ~= "" then
                fname = vim.fn.fnamemodify(fname, ":p:~:.")
            end

            local lnum = (e and e.lnum) or 0
            local col  = (e and e.col) or 0
            local text = (e and e.text) or ""
            if fname == "" then

                ret[i] = string.format("%d:%d: %s", lnum, col, text)
            else
                ret[i] = string.format("%s:%d:%d: %s", fname, lnum, col, text)
            end
        end
    end

    return ret
end

local function ensure_qftf()
    if vim.o.quickfixtextfunc ~= "v:lua.QfPrettyText" then
        vim.o.quickfixtextfunc = "v:lua.QfPrettyText"
    end
end


local function grep_into_qf(query, is_word)
    if not query or query == "" then
        vim.notify("No query", vim.log.levels.WARN)
        return
    end
    if vim.fn.executable("rg") == 0 then
        vim.notify("ripgrep (rg) not found in PATH", vim.log.levels.ERROR)
        return
    end

    set_highlight_for(query, is_word)


    local cmd = "rg --vimgrep -n --smart-case -F " .. vim.fn.shellescape(query)


    vim.cmd("silent! noautocmd keepalt keepjumps keeppatterns cgetexpr systemlist(" .. vim.fn.string(cmd) .. ")")

    if vim.tbl_isempty(vim.fn.getqflist()) then
        vim.cmd("silent! cclose")
        vim.notify("No matches for: " .. query, vim.log.levels.INFO)
        return
    end


    add_file_separators_to_qf()

    ensure_qftf()


    vim.cmd("silent! copen 20 | wincmd p")
    jump_to_next_from_cursor()
end


function _G.GrepWordUnderCursor()
    local word = vim.fn.expand("<cword>")
    grep_into_qf(word, true)
end

function _G.GrepVisualSelection()
    local sel = get_visual_selection_safely()
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "n", false)
    grep_into_qf(sel, false)
end

vim.keymap.set("n", "<leader>g", _G.GrepWordUnderCursor, { desc = "Grep word under cursor (qf + highlight)" })
vim.keymap.set("v", "<leader>g", _G.GrepVisualSelection,  { desc = "Grep visual selection (qf + highlight)" })

vim.keymap.set("n", "<leader>d", function()
    local info = vim.fn.getqflist({ idx = 0, size = 0 })
    if info.size == 0 then
        vim.notify("Quickfix is empty", vim.log.levels.INFO)
        return
    end
    if info.idx == info.size then
        vim.cmd("silent! cfirst | normal! zz")
    else
        vim.cmd("silent! cnext  | normal! zz")
    end
end, { desc = "Next grep match (wraps)" })

vim.keymap.set("n", "<leader>s", function()
    if vim.fn.empty(vim.fn.getqflist()) == 0 then
        vim.cmd("silent! cprevious | normal! zz")
    else
        vim.notify("Quickfix is empty", vim.log.levels.INFO)
    end
end, { desc = "Previous grep match" })


vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true, noremap = true }

    -- Hide search highlights only in the quickfix window
    -- (doesn't change hlsearch at all)
    vim.opt_local.winhighlight = "Search:None,IncSearch:None,CurSearch:None"

    local function open_entry_stay()
      local idx = vim.fn.line(".")
      local info = vim.fn.getqflist({ items = 1 })
      local items = info.items or {}
      if items[idx] and items[idx].valid == 0 then return end
      vim.cmd(("silent! cc %d"):format(idx))
      vim.cmd("wincmd p")
    end

    vim.keymap.set("n", "<CR>",           open_entry_stay, opts)
    vim.keymap.set("n", "<2-LeftMouse>",  open_entry_stay, opts)
    vim.keymap.set("n", "o",              open_entry_stay, opts)
  end,
})

