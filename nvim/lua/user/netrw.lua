-- Root = where nvim started (used by harpoon wrapper too)
_G.ROOT_CWD = _G.ROOT_CWD or vim.fn.getcwd()

-- netrw: do NOT auto-change the global cwd while browsing
vim.g.netrw_keepdir = 1

-- netrw buffer settings (relative numbers, etc.)
vim.g.netrw_bufsettings = "noma nomod nonu nobl nowrap ro rnu"

local aug = vim.api.nvim_create_augroup("CwdNetrwGlue", { clear = true })

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

local function retarget_renamed_buffers(from, to)
    local from_path = normpath(from)
    local to_path = normpath(to)

    for _, target in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(target) then
            local name = vim.api.nvim_buf_get_name(target)
            if name ~= "" and samefile_ignoring_case(name, from_path) then
                vim.api.nvim_buf_call(target, function()
                    vim.cmd("silent keepalt file " .. vim.fn.fnameescape(to_path))
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

-- When netrw opens: open in last tab dir (if any), then resync (fixes "1 behind"),
-- then keep syncing while browsing.
vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = "netrw",
    callback = function(ev)
        local buf = ev.buf

        -- open where you last left netrw in this tab
        if vim.t.netrw_lastdir and vim.t.netrw_lastdir ~= "" then
            win_lcd(vim.t.netrw_lastdir)
        end

        -- netrw updates b:netrw_curdir slightly after FileType fires
        vim.defer_fn(function()
            sync_netrw_dir(buf)
        end, 10)

        -- keep syncing while inside netrw (so entering dirs updates immediately)
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold", "BufEnter" }, {
            group = aug,
            buffer = buf,
            callback = function()
                sync_netrw_dir(buf)
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

-- Open netrw locked to current file dir (window-local)
vim.keymap.set("n", "<leader>e", function()
    local file_dir = vim.fn.expand("%:p:h")
    if file_dir ~= "" then win_lcd(file_dir) end
    vim.cmd("Explore")
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
                vim.cmd("silent! edit")
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
