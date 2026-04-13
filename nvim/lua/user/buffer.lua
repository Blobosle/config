local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function strip_ansi(line)
    line = line:gsub("\27%[[0-9;?]*[ -/]*[@-~]", "")
    line = line:gsub("\27%].-\7", "")
    return line
end

local function extract_command(line)
    line = trim(strip_ansi(line or ""))
    if line == "" then
        return nil
    end

    for _, pattern in ipairs({
        "^.-[%$#>]%s+(.*)$",
        "^.-:%s+(.*)$",
    }) do
        local cmd = line:match(pattern)
        cmd = cmd and trim(cmd) or nil
        if cmd and cmd ~= "" then
            return cmd
        end
    end

    return line
end

local function update_last_command(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].buftype ~= "terminal" then
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
    local cmd = extract_command(line)

    if cmd then
        vim.b[bufnr].terminal_last_command = cmd
    end
end

local function term_label(bufnr)
    local cmd = vim.b[bufnr].terminal_last_command
    if cmd and cmd ~= "" then
        return cmd
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    name = vim.fn.fnamemodify(name, ":t")

    if name == "" then
        return "[terminal " .. bufnr .. "]"
    end

    return name
end

local function terminal_buffers()
    local items = {}

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
            local label = term_label(bufnr)
            items[#items + 1] = {
                bufnr = bufnr,
                label = label,
                ordinal = label .. " " .. bufnr,
            }
        end
    end

    table.sort(items, function(a, b)
        return a.bufnr < b.bufnr
    end)

    return items
end

local function make_terminal_previewer()
    local previewers = require("telescope.previewers")
    local putils = require("telescope.previewers.utils")

    return previewers.new_buffer_previewer({
        title = "Terminal Preview",
        define_preview = function(self, entry)
            local term_bufnr = entry.bufnr

            if not (term_bufnr and vim.api.nvim_buf_is_valid(term_bufnr)) then
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
                    "[terminal buffer unavailable]",
                })
                return
            end

            local lines = vim.api.nvim_buf_get_lines(term_bufnr, 0, -1, false)

            if vim.tbl_isempty(lines) then
                lines = { "[empty terminal buffer]" }
            end

            vim.bo[self.state.bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            vim.bo[self.state.bufnr].modifiable = false

            putils.highlighter(self.state.bufnr, "terminal")
        end,
    })
end

local function open_terminal_buffer_picker()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
        prompt_title = "Terminal Buffers",
        finder = finders.new_table({
            results = terminal_buffers(),
            entry_maker = function(entry)
                return {
                    value = entry,
                    ordinal = entry.ordinal,
                    display = entry.label,
                    bufnr = entry.bufnr,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = make_terminal_previewer(),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()

                if not (selection and selection.bufnr and vim.api.nvim_buf_is_valid(selection.bufnr)) then
                    return
                end

                actions.close(prompt_bufnr)
                vim.cmd("vsplit")
                vim.api.nvim_win_set_buf(0, selection.bufnr)

                vim.cmd("startinsert")
            end)

            return true
        end,
    }):find()
end

local function attach_terminal_tracking(bufnr)
    vim.keymap.set("t", "<CR>", function()
        update_last_command(bufnr)
        return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    end, {
        buffer = bufnr,
        expr = true,
        noremap = true,
        silent = true,
        desc = "Track terminal command",
    })
end

vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*",
    callback = function(args)
        attach_terminal_tracking(args.buf)
    end,
})

vim.keymap.set("n", "<C-b>", open_terminal_buffer_picker, {
    noremap = true,
    silent = true,
    desc = "Pick terminal buffers",
})
