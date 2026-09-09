local M = {}

local api = vim.api

local session_dir = vim.fn.stdpath("state") .. "/nmux/sessions"
local current_socket = vim.v.servername
local current_pid = vim.fn.getpid()
local registry_path = session_dir .. "/" .. current_pid .. ".json"

local function started_from_directory()
    if vim.fn.argc(-1) ~= 1 then
        return false
    end

    local argument = vim.fn.argv(0)
    return type(argument) == "string" and argument ~= "" and vim.fn.isdirectory(argument) == 1
end

local session = {
    started_at = os.time(),
    directory_launcher = started_from_directory(),
    reattached = vim.g.nmux_reattached == true,
    handoff_file = vim.g.nmux_handoff_file or vim.env.NMUX_HANDOFF_FILE,
    ever_had_tui = false,
}

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, { title = "nmux" })
end

local function is_tui_channel(chan)
    local ok, info = pcall(api.nvim_get_chan_info, chan)
    if not ok or type(info) ~= "table" then
        return false
    end

    return type(info.client) == "table" and info.client.name == "nvim-tui"
end

local function has_tui()
    for _, ui in ipairs(api.nvim_list_uis()) do
        if is_tui_channel(ui.chan) then
            return true
        end
    end

    return false
end

local function write_registry()
    if current_socket == "" or not (session.ever_had_tui or session.reattached) then
        return
    end

    local ok, err = pcall(function()
        vim.fn.mkdir(session_dir, "p")
        vim.fn.writefile({ vim.json.encode({
            socket = current_socket,
            pid = current_pid,
            started_at = session.started_at,
        }) }, registry_path)
    end)

    if not ok then
        notify("Could not register this session: " .. tostring(err), vim.log.levels.WARN)
    end
end

local function remove_registry(path)
    if type(path) == "string" and path ~= "" then
        pcall(vim.fn.delete, path)
    end
end

local function mark_as_managed()
    session.ever_had_tui = true
    write_registry()
end

local screen_highlight_fields = {
    { "foreground", "fg", "color" },
    { "background", "bg", "color" },
    { "special", "sp", "color" },
    { "blend", "blend", "number" },
    { "bold", "bold", "boolean" },
    { "standout", "standout", "boolean" },
    { "underline", "underline", "boolean" },
    { "undercurl", "undercurl", "boolean" },
    { "underdouble", "underdouble", "boolean" },
    { "underdotted", "underdotted", "boolean" },
    { "underdashed", "underdashed", "boolean" },
    { "strikethrough", "strikethrough", "boolean" },
    { "italic", "italic", "boolean" },
    { "reverse", "reverse", "boolean" },
    { "nocombine", "nocombine", "boolean" },
}

local function normalize_screen_highlight(attributes)
    local highlight = {}

    for _, field in ipairs(screen_highlight_fields) do
        local value = attributes[field[1]]
        if field[3] == "color" and type(value) == "number" then
            highlight[field[2]] = ("#%06x"):format(value)
        elseif field[3] == "number" and type(value) == "number" then
            highlight[field[2]] = value
        elseif field[3] == "boolean" and value == true then
            highlight[field[2]] = true
        end
    end

    return highlight
end

local function screen_highlight_key(highlight)
    local parts = {}

    for _, field in ipairs(screen_highlight_fields) do
        local value = highlight[field[2]]
        if value ~= nil then
            parts[#parts + 1] = field[2] .. "=" .. tostring(value)
        end
    end

    return table.concat(parts, ",")
end

local function printable_screen_cell(value)
    if type(value) ~= "string" or value == "" then
        return " "
    end

    local byte = value:byte()
    if #value == 1 and byte >= 32 and byte <= 126 then
        return value
    end

    return "?"
end

local function rendered_window_snapshot(position, width, height)
    if type(api.nvim__inspect_cell) ~= "function" then
        return nil, nil
    end

    local lines = {}
    local highlights = {}

    for row = 0, height - 1 do
        local cells = {}
        local spans = {}
        local active_key = ""
        local active_start = nil
        local active_highlight = nil

        for col = 0, width - 1 do
            local ok, cell = pcall(api.nvim__inspect_cell, 1, position[1] + row, position[2] + col)
            if not ok or type(cell) ~= "table" then
                return nil, nil
            end

            cells[#cells + 1] = printable_screen_cell(cell[1])

            local highlight = normalize_screen_highlight(type(cell[2]) == "table" and cell[2] or {})
            local key = screen_highlight_key(highlight)
            if key ~= active_key then
                if active_start ~= nil then
                    spans[#spans + 1] = {
                        start_col = active_start,
                        end_col = col,
                        highlight = active_highlight,
                    }
                end

                active_key = key
                active_start = key ~= "" and col or nil
                active_highlight = key ~= "" and highlight or nil
            end
        end

        if active_start ~= nil then
            spans[#spans + 1] = {
                start_col = active_start,
                end_col = width,
                highlight = active_highlight,
            }
        end

        lines[#lines + 1] = table.concat(cells)
        highlights[#highlights + 1] = spans
    end

    return lines, highlights
end

local function tab_window_snapshots(current_win)
    local windows = {}

    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        local config = api.nvim_win_get_config(win)
        if config.relative == "" then
            local bufnr = api.nvim_win_get_buf(win)
            local position = api.nvim_win_get_position(win)
            local cursor = api.nvim_win_get_cursor(win)
            local view = api.nvim_win_call(win, function()
                local saved = vim.fn.winsaveview()
                return {
                    first = vim.fn.line("w0"),
                    last = vim.fn.line("w$"),
                    leftcol = saved.leftcol or 0,
                }
            end)
            local line_count = api.nvim_buf_line_count(bufnr)
            local first = math.max(1, math.min(view.first, line_count))
            local last = math.max(first, math.min(view.last, line_count))
            local width = api.nvim_win_get_width(win)
            local height = api.nvim_win_get_height(win)
            local screen_lines, screen_highlights = rendered_window_snapshot(position, width, height)

            windows[#windows + 1] = {
                position = position,
                width = width,
                height = height,
                buffer_name = api.nvim_buf_get_name(bufnr),
                modified = vim.bo[bufnr].modified,
                first_line = first,
                leftcol = view.leftcol,
                cursor_line = cursor[1],
                cursor_column = cursor[2],
                lines = api.nvim_buf_get_lines(bufnr, first - 1, last, false),
                screen_lines = screen_lines,
                screen_highlights = screen_highlights,
                is_current = win == current_win,
            }
        end
    end

    table.sort(windows, function(a, b)
        if a.position[1] == b.position[1] then
            return a.position[2] < b.position[2]
        end
        return a.position[1] < b.position[1]
    end)

    return windows
end

local function active_buffer_snapshot()
    local win = api.nvim_get_current_win()
    local bufnr = api.nvim_win_get_buf(win)
    local cursor = api.nvim_win_get_cursor(win)
    local line_count = api.nvim_buf_line_count(bufnr)
    local radius = 100
    local first = math.max(0, cursor[1] - radius - 1)
    local last = math.min(line_count, cursor[1] + radius)
    local lines = api.nvim_buf_get_lines(bufnr, first, last, false)
    local info = vim.fn.getbufinfo(bufnr)[1] or {}
    local name = api.nvim_buf_get_name(bufnr)
    local ui_count = 0

    for _, ui in ipairs(api.nvim_list_uis()) do
        if is_tui_channel(ui.chan) then
            ui_count = ui_count + 1
        end
    end

    if vim.tbl_isempty(lines) then
        lines = { "[empty buffer]" }
    end

    return {
        socket = current_socket,
        pid = current_pid,
        started_at = session.started_at,
        cwd = vim.fn.getcwd(),
        buffer_name = name,
        buftype = vim.bo[bufnr].buftype,
        filetype = vim.bo[bufnr].filetype,
        modified = vim.bo[bufnr].modified,
        lastused = info.lastused or 0,
        tab_count = #api.nvim_list_tabpages(),
        window_count = #api.nvim_list_wins(),
        ui_count = ui_count,
        cursor_line = cursor[1],
        cursor_column = cursor[2],
        preview_first_line = first + 1,
        preview_lines = lines,
        windows = tab_window_snapshots(win),
        discoverable = session.ever_had_tui or session.reattached,
    }
end

function M.snapshot()
    if has_tui() then
        mark_as_managed()
        pcall(api.nvim__redraw, { flush = true })
    end

    return active_buffer_snapshot()
end

function M.adopt(handoff_file)
    if type(handoff_file) ~= "string" or handoff_file == "" then
        return false
    end

    session.reattached = true
    session.handoff_file = handoff_file
    vim.g.nmux_reattached = true
    vim.g.nmux_handoff_file = handoff_file
    write_registry()
    return true
end

local function read_registry(path)
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or not lines or #lines == 0 then
        remove_registry(path)
        return nil
    end

    local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
    if not decoded_ok or type(data) ~= "table" or type(data.socket) ~= "string" then
        remove_registry(path)
        return nil
    end

    data.registry_path = path
    return data
end

local function registry_sockets()
    local sockets = {}

    for _, path in ipairs(vim.fn.globpath(session_dir, "*.json", false, true)) do
        local data = read_registry(path)
        if data then
            sockets[data.socket] = data.registry_path
        end
    end

    return sockets
end

local function rpc_lua(socket, code, args)
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
    if not ok or type(chan) ~= "number" or chan <= 0 then
        return false, "connection failed"
    end

    local request_ok, result = pcall(vim.rpcrequest, chan, "nvim_exec_lua", code, args or {})
    pcall(vim.fn.chanclose, chan)

    if not request_ok then
        return false, result
    end

    return true, result
end

local function session_label(item)
    local cwd = item.cwd ~= "" and item.cwd or "[unknown cwd]"
    local project = vim.fn.fnamemodify(cwd, ":t")
    if project == "" then
        project = cwd
    end

    local filename = item.buffer_name ~= "" and vim.fn.fnamemodify(item.buffer_name, ":t") or "[No Name]"
    return project .. "  " .. filename
end

local function discover_sessions()
    local candidates = registry_sockets()

    local items = {}
    for socket, path in pairs(candidates) do
        if socket ~= current_socket then
            local ok, snapshot = rpc_lua(socket, [[return require("user.nmux").snapshot()]], {})
            if ok and type(snapshot) == "table" and snapshot.discoverable then
                snapshot.registry_path = path or nil
                snapshot.label = session_label(snapshot)
                snapshot.status = snapshot.ui_count > 0 and "attached" or "detached"
                snapshot.ordinal = table.concat({
                    snapshot.cwd or "",
                    snapshot.buffer_name or "",
                    snapshot.status,
                    tostring(snapshot.pid or ""),
                }, " ")
                items[#items + 1] = snapshot
            elseif path then
                remove_registry(path)
            end
        end
    end

    table.sort(items, function(a, b)
        if a.lastused == b.lastused then
            if a.started_at == b.started_at then
                return (a.pid or 0) > (b.pid or 0)
            end
            return (a.started_at or 0) > (b.started_at or 0)
        end
        return (a.lastused or 0) > (b.lastused or 0)
    end)

    return items
end

local function open_backdrop(prompt_bufnr)
    api.nvim_set_hl(0, "TelescopeBackdrop", { bg = "#000000", default = true })

    local bufnr = api.nvim_create_buf(false, true)
    local winid = api.nvim_open_win(bufnr, false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = math.max(1, vim.o.columns),
        height = math.max(1, vim.o.lines - vim.o.cmdheight),
        style = "minimal",
        focusable = false,
        zindex = 40,
    })

    vim.bo[bufnr].bufhidden = "wipe"
    vim.wo[winid].fillchars = "eob: "
    vim.wo[winid].winblend = 35
    vim.wo[winid].winhighlight = "Normal:TelescopeBackdrop,EndOfBuffer:TelescopeBackdrop"

    api.nvim_create_autocmd("BufWipeout", {
        buffer = prompt_bufnr,
        once = true,
        callback = function()
            if api.nvim_win_is_valid(winid) then
                api.nvim_win_close(winid, true)
            end
        end,
    })
end

local function load_telescope()
    local lazy_ok, lazy = pcall(require, "lazy")
    if lazy_ok then
        lazy.load({ plugins = { "telescope.nvim" } })
    end

    local ok = pcall(require, "telescope.pickers")
    if not ok then
        notify("Telescope is unavailable", vim.log.levels.ERROR)
    end
    return ok
end

local function ivy_opts(opts)
    return require("telescope.themes").get_ivy(vim.tbl_deep_extend("force", {
        border = false,
    }, opts or {}))
end

local function ascii_text(text)
    return tostring(text or ""):gsub("[^ -~]", "?")
end

local function render_split_canvas(windows, width, height)
    width = math.max(12, width)
    height = math.max(3, height)

    local canvas = {}
    local highlight_canvas = {}
    for row = 1, height do
        canvas[row] = {}
        highlight_canvas[row] = {}
        for col = 1, width do
            canvas[row][col] = " "
        end
    end

    local function set_cell(row, col, value, highlight)
        if row >= 1 and row <= height and col >= 1 and col <= width then
            canvas[row][col] = value
            highlight_canvas[row][col] = highlight
        end
    end

    local function put_text(row, col, text, last_col, highlight_spans)
        text = ascii_text(text)
        last_col = math.min(last_col, width)
        local span_index = 1

        for index = 1, #text do
            local target_col = col + index - 1
            if target_col > last_col then
                break
            end

            local source_col = index - 1
            while highlight_spans and highlight_spans[span_index]
                and highlight_spans[span_index].end_col <= source_col do
                span_index = span_index + 1
            end

            local span = highlight_spans and highlight_spans[span_index] or nil
            local highlight = span
                and span.start_col <= source_col
                and source_col < span.end_col
                and span.highlight
                or nil
            set_cell(row, target_col, text:sub(index, index), highlight)
        end
    end

    local source_width = 1
    local source_height = 1
    for _, window in ipairs(windows) do
        source_width = math.max(source_width, window.position[2] + window.width)
        source_height = math.max(source_height, window.position[1] + window.height)
    end

    local function scale(value, source_size, target_size)
        return math.floor((value / source_size) * (target_size - 1)) + 1
    end

    local regions = {}
    for _, window in ipairs(windows) do
        local top = scale(window.position[1], source_height, height)
        local left = scale(window.position[2], source_width, width)
        local bottom = scale(window.position[1] + window.height, source_height, height)
        local right = scale(window.position[2] + window.width, source_width, width)

        bottom = math.min(height, math.max(top + 2, bottom))
        right = math.min(width, math.max(left + 3, right))

        for col = left + 1, right - 1 do
            set_cell(top, col, "-")
            set_cell(bottom, col, "-")
        end
        for row = top + 1, bottom - 1 do
            set_cell(row, left, "|")
            set_cell(row, right, "|")
        end
        set_cell(top, left, "+")
        set_cell(top, right, "+")
        set_cell(bottom, left, "+")
        set_cell(bottom, right, "+")

        local filename = window.buffer_name ~= "" and vim.fn.fnamemodify(window.buffer_name, ":t") or "[No Name]"
        local title = (window.is_current and "* " or "") .. filename .. (window.modified and " [+]" or "")
        put_text(top, left + 2, title, right - 2)

        local inner_height = bottom - top - 1
        local inner_width = right - left - 1
        local rendered_lines = window.screen_lines
        local line_source = rendered_lines or window.lines
        local line_total = #line_source
        for row = 1, inner_height do
            local source_index = row
            if line_total > inner_height and inner_height > 1 then
                source_index = math.floor(((row - 1) / (inner_height - 1)) * (line_total - 1)) + 1
            end

            local line = line_source[source_index] or ""
            if not rendered_lines and window.leftcol > 0 then
                line = vim.fn.strcharpart(line, window.leftcol)
            end
            local highlight_spans = rendered_lines
                and window.screen_highlights
                and window.screen_highlights[source_index]
                or nil
            put_text(top + row, left + 1, line, left + inner_width, highlight_spans)
        end

        regions[#regions + 1] = {
            row = top,
            left = left,
            right = right,
            active = window.is_current,
        }
    end

    local lines = {}
    for row = 1, height do
        lines[row] = table.concat(canvas[row])
    end

    local highlights = {}
    for row = 1, height do
        local active_key = ""
        local active_start = nil
        local active_highlight = nil

        for col = 1, width + 1 do
            local highlight = col <= width and highlight_canvas[row][col] or nil
            local key = highlight and screen_highlight_key(highlight) or ""
            if key ~= active_key then
                if active_start ~= nil then
                    highlights[#highlights + 1] = {
                        row = row,
                        start_col = active_start,
                        end_col = col,
                        highlight = active_highlight,
                    }
                end

                active_key = key
                active_start = key ~= "" and col or nil
                active_highlight = key ~= "" and highlight or nil
            end
        end
    end

    return lines, regions, highlights
end

local function render_window_canvas(window, width, height)
    local source_lines = window.screen_lines or {}
    local source_highlights = window.screen_highlights or {}
    local line_total = #source_lines
    local lines = {}
    local highlights = {}

    for row = 1, height do
        local source_index = row
        if line_total > height and height > 1 then
            source_index = math.floor(((row - 1) / (height - 1)) * (line_total - 1)) + 1
        end

        local line = ascii_text(source_lines[source_index] or ""):sub(1, width)
        lines[row] = line

        for _, span in ipairs(source_highlights[source_index] or {}) do
            local start_col = math.max(0, span.start_col)
            local end_col = math.min(#line, span.end_col)
            if start_col < end_col then
                highlights[#highlights + 1] = {
                    row = row,
                    start_col = start_col + 1,
                    end_col = end_col + 1,
                    highlight = span.highlight,
                }
            end
        end
    end

    return lines, highlights
end

local function make_session_previewer()
    local previewers = require("telescope.previewers")
    local putils = require("telescope.previewers.utils")
    local namespace = api.nvim_create_namespace("nmux_preview")
    local color_groups = {}
    local color_group_count = 0

    local function color_group(highlight)
        local key = screen_highlight_key(highlight)
        if key == "" then
            return nil
        end

        if not color_groups[key] then
            color_group_count = color_group_count + 1
            local name = "NmuxPreviewColor" .. color_group_count
            local ok = pcall(api.nvim_set_hl, 0, name, highlight)
            if not ok then
                return nil
            end
            color_groups[key] = name
        end

        return color_groups[key]
    end

    return previewers.new_buffer_previewer({
        title = "Session Preview",
        define_preview = function(self, entry)
            local item = entry.value
            local filename = item.buffer_name ~= "" and item.buffer_name or "[No Name]"
            local modified = item.modified and "modified" or "saved"
            local header = {
                (" %s  ·  %s  ·  pid %s  ·  %d tabs  ·  %d windows "):format(
                    item.status,
                    modified,
                    item.pid,
                    item.tab_count,
                    item.window_count
                ),
                " " .. item.cwd,
                " " .. filename,
                "",
            }
            local header_count = #header
            local windows = item.windows or {}
            local split_regions = nil
            local color_highlights = nil
            local rendered_screen = false
            local content

            if #windows > 1 and self.state.winid and api.nvim_win_is_valid(self.state.winid) then
                local preview_width = api.nvim_win_get_width(self.state.winid)
                local preview_height = math.max(3, api.nvim_win_get_height(self.state.winid) - header_count)
                content, split_regions, color_highlights = render_split_canvas(windows, preview_width, preview_height)
                rendered_screen = true
                vim.bo[self.state.bufnr].filetype = ""
                vim.bo[self.state.bufnr].syntax = ""
            elseif #windows == 1 and windows[1].screen_lines
                and self.state.winid and api.nvim_win_is_valid(self.state.winid) then
                local preview_width = api.nvim_win_get_width(self.state.winid)
                local preview_height = math.max(3, api.nvim_win_get_height(self.state.winid) - header_count)
                content, color_highlights = render_window_canvas(windows[1], preview_width, preview_height)
                rendered_screen = true
                vim.bo[self.state.bufnr].filetype = ""
                vim.bo[self.state.bufnr].syntax = ""
            else
                content = vim.deepcopy(item.preview_lines or { "[preview unavailable]" })
            end

            local lines = vim.list_extend(header, content)

            vim.bo[self.state.bufnr].modifiable = true
            api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            vim.bo[self.state.bufnr].modifiable = false

            if not rendered_screen and item.filetype and item.filetype ~= "" then
                pcall(putils.highlighter, self.state.bufnr, item.filetype)
            end

            api.nvim_buf_clear_namespace(self.state.bufnr, namespace, 0, -1)
            for row = 0, 2 do
                api.nvim_buf_add_highlight(self.state.bufnr, namespace, "TelescopePreviewTitle", row, 0, -1)
            end

            for _, range in ipairs(color_highlights or {}) do
                local group = color_group(range.highlight)
                if group then
                    api.nvim_buf_add_highlight(
                        self.state.bufnr,
                        namespace,
                        group,
                        header_count + range.row - 1,
                        range.start_col - 1,
                        range.end_col - 1
                    )
                end
            end

            if split_regions then
                for _, region in ipairs(split_regions) do
                    api.nvim_buf_add_highlight(
                        self.state.bufnr,
                        namespace,
                        region.active and "NmuxActiveWindow" or "Comment",
                        header_count + region.row - 1,
                        region.left - 1,
                        region.right
                    )
                end
            elseif not rendered_screen and self.state.winid and api.nvim_win_is_valid(self.state.winid) then
                local preview_row = item.cursor_line - item.preview_first_line + 1
                local target_row = math.max(1, math.min(#lines, header_count + preview_row))
                pcall(api.nvim_win_set_cursor, self.state.winid, { target_row, item.cursor_column or 0 })
            end
        end,
    })
end

local function modified_buffers()
    local buffers = {}

    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified then
            local name = api.nvim_buf_get_name(bufnr)
            buffers[#buffers + 1] = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
        end
    end

    return buffers
end

local function clear_handoff(path)
    if type(path) == "string" and path ~= "" then
        pcall(vim.fn.delete, path)
    end
end

local function current_handoff_file()
    return session.handoff_file or vim.g.nmux_handoff_file or vim.env.NMUX_HANDOFF_FILE
end

local function perform_switch(target, disposition)
    local handoff_file = current_handoff_file()
    if type(handoff_file) ~= "string" or handoff_file == "" then
        notify("This Neovim was not started through the nmux-aware nvim() shell wrapper", vim.log.levels.ERROR)
        return
    end

    if disposition == "quit" then
        local dirty = modified_buffers()
        if #dirty > 0 then
            notify("Switch cancelled; save or discard modified buffers first: " .. table.concat(dirty, ", "), vim.log.levels.WARN)
            return
        end
    end

    local alive, snapshot = rpc_lua(target.socket, [[return require("user.nmux").snapshot()]], {})
    if not alive or type(snapshot) ~= "table" or not snapshot.discoverable then
        remove_registry(target.registry_path)
        notify("The selected Neovim session is no longer available", vim.log.levels.WARN)
        return
    end

    local adopted, result = rpc_lua(
        target.socket,
        [[return require("user.nmux").adopt(...)]],
        { handoff_file }
    )
    if not adopted or result ~= true then
        notify("Could not prepare the selected session for attachment", vim.log.levels.ERROR)
        return
    end

    local wrote, write_err = pcall(vim.fn.writefile, { target.socket }, handoff_file)
    if not wrote then
        notify("Could not queue the selected session: " .. tostring(write_err), vim.log.levels.ERROR)
        return
    end

    if disposition == "keep" then
        session.reattached = true
        vim.g.nmux_reattached = true
        write_registry()
        pcall(api.nvim__redraw, { flush = true })

        local detached, detach_err = pcall(vim.cmd, "detach")
        if not detached then
            clear_handoff(handoff_file)
            notify("Could not detach this session: " .. tostring(detach_err), vim.log.levels.ERROR)
        end
        return
    end

    local quit, quit_err = pcall(vim.cmd, "qall")
    if not quit then
        clear_handoff(handoff_file)
        notify("Could not quit this session: " .. tostring(quit_err), vim.log.levels.ERROR)
    end
end

local function confirm_disposition(target)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local choices = {
        { label = "Keep current session running", disposition = "keep" },
        { label = "Quit current session", disposition = "quit" },
    }

    pickers.new(ivy_opts({
        layout_config = { height = 8 },
        previewer = false,
    }), {
        prompt_title = "Current Neovim Session",
        finder = finders.new_table({
            results = choices,
            entry_maker = function(choice)
                return {
                    value = choice,
                    display = choice.label,
                    ordinal = choice.label,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            open_backdrop(prompt_bufnr)
            actions.select_default:replace(function()
                local selected = action_state.get_selected_entry()
                if not selected then
                    return
                end

                actions.close(prompt_bufnr)
                vim.schedule(function()
                    perform_switch(target, selected.value.disposition)
                end)
            end)
            return true
        end,
    }):find()
end

local function select_session(target)
    if session.reattached then
        perform_switch(target, "keep")
    elseif session.directory_launcher then
        perform_switch(target, "quit")
    else
        confirm_disposition(target)
    end
end

local function open_session_picker()
    if not load_telescope() then
        return
    end

    local items = discover_sessions()
    if #items == 0 then
        notify("No other running Neovim sessions")
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local entry_display = require("telescope.pickers.entry_display")

    api.nvim_set_hl(0, "NmuxAttached", { link = "DiagnosticOk", default = true })
    api.nvim_set_hl(0, "NmuxDetached", { link = "SpecialComment", default = true })
    api.nvim_set_hl(0, "NmuxActiveWindow", { link = "DiagnosticOk", default = true })

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 10 },
            { remaining = true },
            { width = 9, right_justify = true },
        },
    })

    pickers.new(ivy_opts({
        layout_config = {
            height = 25,
            preview_width = 0.55,
        },
    }), {
        prompt_title = "Neovim Sessions",
        finder = finders.new_table({
            results = items,
            entry_maker = function(item)
                return {
                    value = item,
                    ordinal = item.ordinal,
                    display = function()
                        return displayer({
                            { item.status, item.status == "attached" and "NmuxAttached" or "NmuxDetached" },
                            item.label,
                            "pid " .. item.pid,
                        })
                    end,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = make_session_previewer(),
        attach_mappings = function(prompt_bufnr)
            open_backdrop(prompt_bufnr)
            actions.select_default:replace(function()
                local selected = action_state.get_selected_entry()
                if not selected then
                    return
                end

                actions.close(prompt_bufnr)
                vim.schedule(function()
                    select_session(selected.value)
                end)
            end)
            return true
        end,
    }):find()
end

session.ever_had_tui = has_tui()
if session.ever_had_tui or session.reattached then
    write_registry()
end

local group = api.nvim_create_augroup("NmuxSession", { clear = true })
api.nvim_create_autocmd("UIEnter", {
    group = group,
    callback = function()
        if is_tui_channel(vim.v.event.chan) then
            mark_as_managed()
        end
    end,
})
api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
        remove_registry(registry_path)
    end,
})

vim.keymap.set("n", "<C-o>", open_session_picker, {
    noremap = true,
    silent = true,
    desc = "Switch Neovim session",
})

return M
