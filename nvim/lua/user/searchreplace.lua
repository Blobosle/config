local M = {}

local ns = vim.api.nvim_create_namespace("user.cmdwin_preview")
local aug = vim.api.nvim_create_augroup("UserCmdwinPreview", { clear = true })

local state = nil
local last_source = nil

local substitute_cmds = {
    substitute = true,
    smagic = true,
    snomagic = true,
}

local function is_valid_win(win)
    return win and win ~= 0 and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
    return buf and buf ~= 0 and vim.api.nvim_buf_is_valid(buf)
end

local function is_previewable_target(win, buf)
    if not is_valid_win(win) or not is_valid_buf(buf) then
        return false
    end

    if vim.api.nvim_win_get_config(win).relative ~= "" then
        return false
    end

    if vim.bo[buf].buftype ~= "" then
        return false
    end

    return true
end

local function set_source()
    last_source = {
        win = vim.api.nvim_get_current_win(),
        buf = vim.api.nvim_get_current_buf(),
    }
end

local function feed(keys)
    vim.api.nvim_feedkeys(keys, "n", false)
end

function M.keys(prefix)
    set_source()
    return "q:i" .. (prefix or "")
end

function M.visual_keys(prefix)
    set_source()
    return "q:$a" .. (prefix or "")
end

function M.open(prefix)
    feed(M.keys(prefix))
end

function M.open_visual(prefix)
    feed(M.visual_keys(prefix))
end

local function clear_preview()
    if not state then
        return
    end

    if is_valid_buf(state.target_buf) then
        vim.api.nvim_buf_clear_namespace(state.target_buf, ns, 0, -1)
    end
end

local function restore_window_opts()
    if not state or not is_valid_win(state.target_win) then
        return
    end

    if state.saved_conceallevel ~= nil then
        vim.wo[state.target_win].conceallevel = state.saved_conceallevel
    end
    if state.saved_concealcursor ~= nil then
        vim.wo[state.target_win].concealcursor = state.saved_concealcursor
    end
end

local function teardown()
    clear_preview()
    restore_window_opts()
    state = nil
end

local function resolve_source_win()
    if is_valid_win(last_source and last_source.win) then
        return last_source.win
    end

    local alt = vim.fn.win_getid(vim.fn.winnr("#"))
    if is_valid_win(alt) and alt ~= vim.api.nvim_get_current_win() then
        return alt
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= vim.api.nvim_get_current_win() and vim.api.nvim_win_get_config(win).relative == "" then
            return win
        end
    end
end

local function parse_substitute_arg(arg)
    if type(arg) ~= "string" or arg == "" then
        return nil
    end

    local delimiter = arg:sub(1, 1)
    if delimiter == "" then
        return nil
    end

    local parts = { "", "" }
    local index = 1
    local section = 1
    local closed_pattern = false
    local closed_replacement = false

    while index < #arg do
        index = index + 1
        local char = arg:sub(index, index)

        if char == "\\" and index < #arg then
            parts[section] = parts[section] .. char .. arg:sub(index + 1, index + 1)
            index = index + 1
        elseif char == delimiter then
            if section == 1 then
                closed_pattern = true
                section = 2
            else
                closed_replacement = true
                break
            end
        else
            parts[section] = parts[section] .. char
        end
    end

    local flags = ""
    if closed_replacement and index < #arg then
        flags = arg:sub(index + 1)
    end

    local stage = "pattern"
    if closed_pattern then
        stage = "replacement"
    end
    if closed_replacement then
        stage = "flags"
    end

    return {
        delimiter = delimiter,
        pattern = parts[1],
        replacement = parts[2],
        flags = flags,
        stage = stage,
    }
end

local function normalize_pattern(cmd, pattern, flags)
    if pattern == "" then
        pattern = vim.fn.getreg("/")
    end
    if pattern == "" then
        return nil
    end

    if flags:find("I", 1, true) then
        pattern = "\\C" .. pattern
    elseif flags:find("i", 1, true) then
        pattern = "\\c" .. pattern
    end

    if cmd == "smagic" then
        pattern = "\\m" .. pattern
    elseif cmd == "snomagic" then
        pattern = "\\M" .. pattern
    end

    return pattern
end

local function get_range(parsed)
    if parsed.range and #parsed.range > 0 then
        local line1 = parsed.range[1]
        local line2 = parsed.range[#parsed.range]
        if line1 > line2 then
            line1, line2 = line2, line1
        end
        return line1, line2
    end

    local line = vim.api.nvim_win_get_cursor(state.target_win)[1]
    return line, line
end

local function highlight_search(line1, line2, pattern)
    local buf = state.target_buf
    local lines = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)

    for offset, text in ipairs(lines) do
        local row = line1 + offset - 2
        local start_col = 0

        while true do
            local match = vim.fn.matchstrpos(text, pattern, start_col)
            local col1 = match[2]
            local col2 = match[3]
            if col1 < 0 then
                break
            end

            vim.api.nvim_buf_set_extmark(buf, ns, row, col1, {
                end_row = row,
                end_col = col2,
                hl_group = "Search",
                priority = 250,
            })

            start_col = math.max(col2, col1 + 1)
        end
    end
end

local function replacement_flags(flags)
    local cleaned = flags:gsub("[gIi]", "")
    return cleaned
end

local function preview_line_substitute(row, text, pattern, replacement, flags)
    local start_col = 0
    local preview_once = not flags:find("g", 1, true)

    while true do
        local match = vim.fn.matchstrpos(text, pattern, start_col)
        local col1 = match[2]
        local col2 = match[3]
        if col1 < 0 then
            break
        end

        if col2 <= col1 then
            start_col = col1 + 1
        else
            local matched = text:sub(col1 + 1, col2)
            local ok, replaced = pcall(vim.fn.substitute, matched, pattern, replacement, replacement_flags(flags))
            if ok and replaced ~= matched then
                vim.api.nvim_buf_set_extmark(state.target_buf, ns, row, col1, {
                    end_row = row,
                    end_col = col2,
                    hl_group = "Substitute",
                    conceal = "",
                    virt_text = replaced == "" and nil or { { replaced, "Substitute" } },
                    virt_text_pos = "inline",
                    priority = 300,
                })
            end

            start_col = col2
        end

        if preview_once then
            break
        end
    end
end

local function preview_substitute(line1, line2, pattern, replacement, flags)
    local lines = vim.api.nvim_buf_get_lines(state.target_buf, line1 - 1, line2, false)
    for offset, text in ipairs(lines) do
        preview_line_substitute(line1 + offset - 2, text, pattern, replacement, flags)
    end
end

local function update_preview_now()
    if not state or not is_valid_buf(state.cmdwin_buf) or vim.api.nvim_get_current_buf() ~= state.cmdwin_buf then
        return
    end

    clear_preview()

    local line = vim.api.nvim_get_current_line()
    if line == "" then
        return
    end

    local ok, parsed = pcall(vim.api.nvim_win_call, state.target_win, function()
        return vim.api.nvim_parse_cmd(line, {})
    end)
    if not ok or not substitute_cmds[parsed.cmd] then
        return
    end

    local spec = parse_substitute_arg(parsed.args[1] or "")
    if not spec then
        return
    end

    local pattern = normalize_pattern(parsed.cmd, spec.pattern, spec.flags)
    if not pattern then
        return
    end

    local line1, line2 = get_range(parsed)
    if spec.stage == "pattern" then
        highlight_search(line1, line2, pattern)
        return
    end

    preview_substitute(line1, line2, pattern, spec.replacement, spec.flags)
end

local function schedule_update()
    if not state then
        return
    end

    state.tick = (state.tick or 0) + 1
    local tick = state.tick
    vim.defer_fn(function()
        if state and state.tick == tick then
            pcall(update_preview_now)
        end
    end, 15)
end

function M.setup()
    vim.api.nvim_create_autocmd("CmdwinEnter", {
        group = aug,
        pattern = ":",
        callback = function()
            local target_win = resolve_source_win()
            local target_buf = target_win and vim.api.nvim_win_get_buf(target_win) or nil
            if not is_previewable_target(target_win, target_buf) then
                return
            end

            state = {
                cmdwin_buf = vim.api.nvim_get_current_buf(),
                target_win = target_win,
                target_buf = target_buf,
                saved_conceallevel = vim.wo[target_win].conceallevel,
                saved_concealcursor = vim.wo[target_win].concealcursor,
                tick = 0,
            }

            vim.wo[target_win].conceallevel = math.max(vim.wo[target_win].conceallevel, 2)
            if not vim.wo[target_win].concealcursor:find("n", 1, true) then
                vim.wo[target_win].concealcursor = vim.wo[target_win].concealcursor .. "n"
            end

            local local_group = vim.api.nvim_create_augroup("UserCmdwinPreview_" .. state.cmdwin_buf, { clear = true })
            vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI", "InsertLeave" }, {
                group = local_group,
                buffer = state.cmdwin_buf,
                callback = schedule_update,
            })
            vim.api.nvim_create_autocmd("CmdwinLeave", {
                group = local_group,
                once = true,
                callback = teardown,
            })
            vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
                group = local_group,
                buffer = state.cmdwin_buf,
                once = true,
                callback = teardown,
            })

            schedule_update()
        end,
    })
end

return M
