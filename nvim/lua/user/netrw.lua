-- Root = where nvim started (used by harpoon wrapper too)
_G.ROOT_CWD = _G.ROOT_CWD or vim.fn.getcwd()

-- netrw: do NOT auto-change the global cwd while browsing
vim.g.netrw_keepdir = 1

-- netrw buffer settings (relative numbers, etc.)
vim.g.netrw_bufsettings = "noma nomod nonu nobl nowrap ro rnu"

local aug = vim.api.nvim_create_augroup("CwdNetrwGlue", { clear = true })
local comfy_statuscolumn = '%=%s%=%{v:virtnum > 0 ? "" : v:lua.netrw_comfy_label(v:lnum, v:relnum)} '
local comfy_labels

local function get_comfy_labels()
    if comfy_labels then
        return comfy_labels
    end

    local ok, comfy = pcall(require, "comfy-line-numbers")
    comfy_labels = (ok and comfy.config and comfy.config.labels) or {}
    return comfy_labels
end

_G.netrw_comfy_label = function(absnum, relnum)
    local width = vim.wo.numberwidth

    if relnum == 0 then
        return string.format("%" .. width .. "d", absnum)
    end

    local labels = get_comfy_labels()
    if relnum > 0 and relnum <= #labels then
        return string.format("%" .. width .. "s", labels[relnum])
    end

    return string.format("%" .. width .. "d", absnum)
end

local function clear_netrw_comfy(win)
    if not win or win == -1 or not vim.api.nvim_win_is_valid(win) then return end
    if vim.wo[win].statuscolumn ~= comfy_statuscolumn then return end
    vim.wo[win].statuscolumn = ""
end

local function apply_netrw_comfy(win, buf)
    if not win or win == -1 or not vim.api.nvim_win_is_valid(win) then return end
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.bo[buf].filetype ~= "netrw" then return end

    if not vim.wo[win].relativenumber then
        clear_netrw_comfy(win)
        return
    end

    vim.api.nvim_win_call(win, function()
        vim.wo.numberwidth = math.max(4, #tostring(vim.api.nvim_buf_line_count(buf)))
        vim.wo.statuscolumn = comfy_statuscolumn
    end)
end

local function map_netrw_comfy(buf)
    if vim.b[buf].comfy_line_numbers_mapped then return end

    for index, label in ipairs(get_comfy_labels()) do
        vim.keymap.set({ "n", "v", "o" }, label .. "k", index .. "k", {
            buffer = buf,
            noremap = true,
            silent = true,
        })
        vim.keymap.set({ "n", "v", "o" }, label .. "<Up>", index .. "k", {
            buffer = buf,
            noremap = true,
            silent = true,
        })
        vim.keymap.set({ "n", "v", "o" }, label .. "j", index .. "j", {
            buffer = buf,
            noremap = true,
            silent = true,
        })
        vim.keymap.set({ "n", "v", "o" }, label .. "<Down>", index .. "j", {
            buffer = buf,
            noremap = true,
            silent = true,
        })
    end

    vim.b[buf].comfy_line_numbers_mapped = true
end

local function first_netrw_entry_line(buf)
    for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        local trimmed = vim.trim(line)
        if trimmed ~= "" and not trimmed:match('^"') then
            return lnum
        end
    end
end

local function win_lcd(dir)
    if not dir or dir == "" then return end
    pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(dir))
end

local function normpath(path)
    return vim.fn.fnamemodify(path or "", ":p")
end

local function samefile_ignoring_case(a, b)
    local ap = normpath(a)
    local bp = normpath(b)
    if ap == "" or bp == "" then
        return false
    end
    return ap:lower() == bp:lower()
end

local function rename_path(from, to)
    if not samefile_ignoring_case(from, to) or from == to then
        return vim.fn.rename(from, to)
    end

    local tmp = ("%s.__netrw_case_rename__.%d"):format(from, vim.loop.hrtime())
    local first = vim.fn.rename(from, tmp)
    if first ~= 0 then
        return first
    end

    local second = vim.fn.rename(tmp, to)
    if second ~= 0 then
        vim.fn.rename(tmp, from)
        return second
    end

    return 0
end

local function netrw_target_path()
    local name = vim.fn.expand("<cfile>")
    if not name or name == "" then
        return nil
    end

    local dir = vim.b.netrw_curdir or vim.fn.getcwd()
    return normpath(dir .. "/" .. name)
end

local function retarget_renamed_buffers(from, to)
    local from_path = normpath(from)
    local to_path = normpath(to)

    for _, target in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(target) then
            local name = vim.api.nvim_buf_get_name(target)
            if name ~= "" and samefile_ignoring_case(name, from_path) then
                vim.api.nvim_buf_call(target, function()
                    if vim.bo[target].modified then
                        vim.cmd("silent keepalt file " .. vim.fn.fnameescape(to_path))
                        return
                    end

                    -- :file leaves the buffer in Vim's "not edited" state, which
                    -- triggers E13 on the next :write. Retarget clean buffers with
                    -- :saveas! so later saves behave like a normal edited file.
                    vim.cmd("silent noautocmd keepalt saveas! " .. vim.fn.fnameescape(to_path))

                    local stale = vim.fn.bufnr(from_path)
                    if stale ~= -1 and stale ~= target and vim.api.nvim_buf_is_valid(stale) then
                        vim.cmd("silent! bdelete! " .. stale)
                    end
                end)
            end
        end
    end
end

local function sync_netrw_dir(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.bo[buf].filetype ~= "netrw" then return end

    local dir = vim.b[buf].netrw_curdir
    if dir and dir ~= "" then
        -- remember last dir per-tab
        vim.t.netrw_lastdir = dir

        -- lock the current netrw window to netrw's true current dir
        if vim.api.nvim_get_current_buf() == buf then
            win_lcd(dir)
        end
    end
end

local function refresh_current_view()
    vim.schedule(function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

        if vim.bo[buf].filetype ~= "netrw" then
            vim.cmd("silent! edit")
            return
        end

        local dir = vim.b[buf].netrw_curdir or vim.fn.getcwd()
        local view = vim.fn.winsaveview()
        vim.fn["netrw#Explore"](0, 0, 0, dir)

        if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_call(win, function()
                local line_count = vim.api.nvim_buf_line_count(0)
                view.lnum = math.min(view.lnum, line_count)
                pcall(vim.fn.winrestview, view)
            end)
        end
    end)
end

-- When netrw opens: open in last tab dir (if any), then resync (fixes "1 behind"),
-- then keep syncing while browsing.
vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = "netrw",
    callback = function(ev)
        local buf = ev.buf
        local win = vim.fn.bufwinid(buf)

        map_netrw_comfy(buf)
        vim.keymap.set("n", "{", function()
            local first_entry = first_netrw_entry_line(buf)
            if first_entry and vim.fn.line(".") > first_entry then
                vim.cmd("normal! m'")
                vim.api.nvim_win_set_cursor(0, { first_entry, 0 })
                return
            end

            vim.cmd("normal! {")
        end, { buffer = buf, silent = true })
        vim.keymap.set("n", "}", function()
            local first_entry = first_netrw_entry_line(buf)
            if first_entry and vim.fn.line(".") < first_entry then
                vim.cmd("normal! m'")
                vim.api.nvim_win_set_cursor(0, { first_entry, 0 })
                return
            end

            vim.cmd("normal! }")
        end, { buffer = buf, silent = true })
        apply_netrw_comfy(win, buf)

        -- open where you last left netrw in this tab
        if vim.t.netrw_lastdir and vim.t.netrw_lastdir ~= "" then
            win_lcd(vim.t.netrw_lastdir)
        end

        -- netrw updates b:netrw_curdir slightly after FileType fires
        vim.defer_fn(function()
            sync_netrw_dir(buf)
            apply_netrw_comfy(vim.fn.bufwinid(buf), buf)
        end, 10)

        -- keep syncing while inside netrw (so entering dirs updates immediately)
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold", "BufEnter" }, {
            group = aug,
            buffer = buf,
            callback = function()
                sync_netrw_dir(buf)
                apply_netrw_comfy(vim.fn.bufwinid(buf), buf)
            end,
        })
    end,
})

-- When entering a real file buffer, cd GLOBAL to that file's directory
-- (this makes memento + normal navigation behave how you want)
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = aug,
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" then return end
        if vim.fn.isdirectory(name) == 1 then return end

        local ft = vim.bo[buf].filetype
        if ft == "netrw" or ft == "terminal" or ft == "help" then return end

        local dir = vim.fn.fnamemodify(name, ":p:h")
        pcall(vim.cmd, "cd " .. vim.fn.fnameescape(dir))
    end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = aug,
    callback = function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)

        if vim.bo[buf].filetype == "netrw" then
            apply_netrw_comfy(win, buf)
            return
        end

        clear_netrw_comfy(win)
    end,
})

-- Open netrw locked to current file dir (window-local)
vim.keymap.set("n", "<leader>e", function()
    if vim.bo.filetype == "netrw" then
        sync_netrw_dir(vim.api.nvim_get_current_buf())
        for lnum = 1, vim.api.nvim_buf_line_count(0) do
            local line = vim.trim(vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or "")
            if line == "../" or line == ".." then
                vim.api.nvim_win_set_cursor(0, { lnum, 0 })
                return
            end
        end

        vim.cmd("normal! gg")
        return
    end

    local file_name = vim.fn.expand("%:t")
    local file_dir = vim.fn.expand("%:p:h")
    if file_dir ~= "" then win_lcd(file_dir) end
    vim.cmd("Explore")
    if file_name ~= "" then
        vim.schedule(function()
            if vim.bo.filetype ~= "netrw" then return end

            for lnum = 1, vim.api.nvim_buf_line_count(0) do
                local line = vim.trim(vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or "")
                if line == file_name then
                    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
                    return
                end
            end
        end)
    end
end, { desc = "Explore (locked to file dir)" })

-- Open netrw in a new tab locked to current file dir
vim.keymap.set("n", "<leader>w", function()
    local file_dir = vim.fn.expand("%:p:h")
    vim.cmd("tabnew")
    if file_dir ~= "" then win_lcd(file_dir) end
    vim.cmd("Explore")
end, { desc = "Explore in new tab (locked)" })

-- Renaming inside of a buffer
vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(ev)
        local original_x = vim.fn.maparg("x", "n", false, true)

        vim.keymap.set("n", "x", function()
            local target = netrw_target_path()
            if target and vim.fn.filereadable(target) == 1 and vim.fn.executable(target) == 1 then
                _G.run_in_term_vsplit(vim.fn.shellescape(target), vim.fn.fnamemodify(target, ":h"))
                return
            end

            if type(original_x) == "table" and original_x.rhs and original_x.rhs ~= "" then
                local keys = vim.api.nvim_replace_termcodes(original_x.rhs, true, false, true)
                vim.api.nvim_feedkeys(keys, "n", false)
                return
            end

            vim.fn["netrw#BrowseX"](target or vim.fn.expand("<cfile>"), 0)
        end, { buffer = ev.buf, silent = true })

        vim.keymap.set("n", "R", function()
            local name = vim.fn.expand("<cfile>")
            local dir = vim.b.netrw_curdir or vim.fn.getcwd()
            local from = normpath(dir .. "/" .. name)

            vim.cmd("belowright 1new")
            local buf = vim.api.nvim_get_current_buf()

            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].swapfile = false
            vim.bo[buf].modifiable = true
            vim.bo[buf].readonly = false

            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { from })
            vim.api.nvim_win_set_cursor(0, { 1, #from + 1 })

            local function apply()
                local to = normpath(vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""))

                if to == "" or to == from then
                    vim.cmd("bd!")
                    return
                end

                local ok = rename_path(from, to)
                if ok ~= 0 then
                    vim.notify("rename failed: " .. from .. " -> " .. to, vim.log.levels.ERROR)
                    return
                end

                retarget_renamed_buffers(from, to)
                vim.cmd("bd!")
                refresh_current_view()
            end

            vim.keymap.set("n", "<CR>", apply, { buffer = buf, silent = true })
            vim.keymap.set("i", "<CR>", function()
                vim.cmd("stopinsert")
                apply()
            end, { buffer = buf, silent = true })

            vim.keymap.set("n", "q", "<cmd>bd!<cr>", { buffer = buf, silent = true })
            vim.keymap.set("n", "<Esc>", "<cmd>bd!<cr>", { buffer = buf, silent = true })
        end, { buffer = ev.buf, silent = true })
    end,
})
