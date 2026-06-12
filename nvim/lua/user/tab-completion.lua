local edit_cmds = { e = true, ed = true, edi = true, edit = true }
local sh_cmds = { sh = true, shin = true, shr = true }

local function key(keys)
    return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function escaped_at(text, idx)
    local n = 0
    for i = idx - 1, 1, -1 do
        if text:sub(i, i) ~= "\\" then
            break
        end
        n = n + 1
    end
    return n % 2 == 1
end

local function arg_start(text, min)
    for i = #text, min, -1 do
        if text:sub(i, i):match("%s") and not escaped_at(text, i) then
            return i + 1
        end
    end
    return min
end

local function complete_at(start_col, arglead, completion_type)
    completion_type = completion_type or "file"

    local matches = vim.fn.getcompletion(arglead, completion_type)
    if #matches == 0 then
        return false
    end

    if completion_type == "file" then
        matches = vim.tbl_map(vim.fn.fnameescape, matches)
    end

    local buf = vim.api.nvim_get_current_buf()
    vim.schedule(function()
        if vim.api.nvim_get_current_buf() == buf and vim.fn.mode() == "i" then
            vim.fn.complete(start_col, matches)
        end
    end)

    return true
end

local function complete_sh_arg(before, cmd_end)
    local after_cmd = before:sub(cmd_end + 1)
    if after_cmd == "" then
        return complete_at(cmd_end + 2, "", "shellcmd") and " " or key("<Tab>")
    end
    if not after_cmd:sub(1, 1):match("%s") then
        return key("<Tab>")
    end

    local start = arg_start(before, cmd_end + 1)
    local args = after_cmd:gsub("^%s*", "")
    local completion_type = args:find("%s") and "file" or "shellcmd"
    return complete_at(start, before:sub(start), completion_type) and "" or key("<Tab>")
end

local function complete_cmdwin()
    if vim.fn.pumvisible() == 1 then
        return key("<C-n>")
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before = line:sub(1, col)
    local _, cmd_end, cmd = before:find("^%s*'<,'>%s*([%a][%w]*)!?")
    if not cmd then
        _, cmd_end, cmd = before:find("^%s*([%a][%w]*)!?")
    end

    if not (cmd and edit_cmds[cmd:lower()]) then
        if cmd and sh_cmds[cmd:lower()] then
            return complete_sh_arg(before, cmd_end)
        end
        return key("<Tab>")
    end

    local after_cmd = before:sub(cmd_end + 1)
    if after_cmd == "" then
        return complete_at(cmd_end + 2, "") and " " or key("<Tab>")
    end
    if not after_cmd:sub(1, 1):match("%s") then
        return key("<Tab>")
    end

    local start = arg_start(before, cmd_end + 1)
    return complete_at(start, before:sub(start)) and "" or key("<Tab>")
end

vim.api.nvim_create_autocmd("CmdwinEnter", {
    group = vim.api.nvim_create_augroup("UserTabCompletion", { clear = true }),
    callback = function()
        if vim.fn.getcmdwintype() == ":" then
            vim.keymap.set("i", "<Tab>", complete_cmdwin, {
                buffer = true,
                expr = true,
                desc = "Complete command-window arguments",
            })
        end
    end,
})
