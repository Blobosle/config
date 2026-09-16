local M = {}

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, { title = "cx" })
end

local function cx_binary()
    local installed = vim.fn.exepath("cx")
    if installed ~= "" then
        return installed
    end
    local local_build = vim.fn.stdpath("config") .. "/cx/cx"
    if vim.fn.executable(local_build) == 1 then
        return local_build
    end
    return nil
end

local function current_directory()
    if type(_G.terminal_cwd) == "function" then
        local cwd = _G.terminal_cwd(vim.api.nvim_get_current_buf())
        if cwd then
            return cwd
        end
    end
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" then
        local directory = vim.fn.fnamemodify(name, ":p:h")
        if vim.fn.isdirectory(directory) == 1 then
            return directory
        end
    end
    return vim.fn.getcwd()
end

local function run(args, opts)
    opts = opts or {}
    local binary = cx_binary()
    if not binary then
        return nil, "cx is not installed; run `go build -o cx ./cmd/cx` in ~/.config/nvim/cx"
    end
    local command = { binary }
    vim.list_extend(command, args)
    local result = vim.system(command, {
        cwd = opts.cwd or current_directory(),
        text = true,
        env = { CX_CALLER_NVIM = vim.v.servername },
    }):wait()
    if result.code ~= 0 then
        return nil, vim.trim(result.stderr ~= "" and result.stderr or result.stdout)
    end
    return result.stdout, nil
end

local function load_items(global)
    local args = { "list", "--json" }
    if global then
        args[#args + 1] = "--global"
    end
    local output, err = run(args)
    if not output then
        return nil, err
    end
    local ok, items = pcall(vim.json.decode, output)
    if not ok or type(items) ~= "table" then
        return nil, "cx returned invalid Task data"
    end
    return items
end

local function rpc_preview(socket)
    if socket == vim.v.servername then
        local ok, snapshot = pcall(function()
            return require("user.nmux").snapshot()
        end)
        return ok and snapshot or nil
    end
    local ok, channel = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
    if not ok or channel <= 0 then
        return nil
    end
    local requested, snapshot = pcall(
        vim.rpcrequest,
        channel,
        "nvim_exec_lua",
        [[return require("user.cx").rpc({ method = "preview" })]],
        {}
    )
    pcall(vim.fn.chanclose, channel)
    return requested and snapshot or nil
end

local function previewer()
    local previewers = require("telescope.previewers")
    return previewers.new_buffer_previewer({
        title = "Task Neovim",
        define_preview = function(self, entry)
            local item = entry.value
            local snapshot = rpc_preview(item.nvim_socket)
            local lines = {
                item.message,
                item.branch,
                item.status .. (item.attached and " · attached" or " · detached"),
                item.worktree,
                "",
            }
            if snapshot and snapshot.preview_lines then
                vim.list_extend(lines, snapshot.preview_lines)
            else
                lines[#lines + 1] = "Neovim preview unavailable"
            end
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
    })
end

local function root_pinned_sorter()
    local conf = require("telescope.config").values
    local base = conf.generic_sorter({})
    local Sorter = require("telescope.sorters").Sorter
    return Sorter:new({
        discard = base.discard,
        scoring_function = function(_, prompt, line, entry, cb_add, cb_filter)
            local score = base:scoring_function(prompt, line, entry, cb_add, cb_filter)
            if score < 0 then
                return score
            end
            if entry.value.kind == "root" then
                return 0
            end
            return score + 1
        end,
        highlighter = function(_, prompt, display)
            return base:highlighter(prompt, display)
        end,
    })
end

local function run_action(item, args, after)
    local output, err = run(args, { cwd = item.project_scope })
    if not output then
        notify(err, vim.log.levels.ERROR)
        return
    end
    if output ~= "" then
        notify(vim.trim(output))
    end
    if after then
        after()
    end
end

local function attach(item)
    if item.nvim_socket == vim.v.servername then
        notify("Already attached to " .. item.message)
        return
    end
    local ok = require("user.cx").rpc({
        method = "handoff",
        params = { socket = item.nvim_socket },
    })
    if not ok then
        notify("UI handoff requires the nmux-aware nvim() shell wrapper", vim.log.levels.ERROR)
    end
end

local function open_diff(item)
    if item.kind ~= "task" then
        notify("Root has no Task diff", vim.log.levels.WARN)
        return
    end
    local output, err = run({ "diff", item.id }, { cwd = item.project_scope })
    if not output then
        notify(err, vim.log.levels.ERROR)
        return
    end
    vim.cmd("new")
    local buffer = vim.api.nvim_get_current_buf()
    vim.bo[buffer].buftype = "nofile"
    vim.bo[buffer].bufhidden = "wipe"
    vim.bo[buffer].filetype = "diff"
    vim.api.nvim_buf_set_name(buffer, "cx://diff/" .. item.id)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(output, "\n", { plain = true }))
    vim.bo[buffer].modifiable = false
end

local function prompt_send(item)
    if item.kind ~= "task" then
        notify("Messages can only be sent to Tasks", vim.log.levels.WARN)
        return
    end
    vim.ui.input({ prompt = "Send to " .. item.message .. ": " }, function(message)
        if message and message ~= "" then
            if item.nvim_socket == vim.v.servername then
                local sent = require("user.cx").rpc({ method = "send", params = { message = message } })
                if not sent then
                    notify("Task terminal is unavailable", vim.log.levels.ERROR)
                end
            else
                run_action(item, { "send", item.id, message })
            end
        end
    end)
end

local function ask_and_attach(item, operation)
    if item.kind ~= "task" then
        notify(operation .. " requires a Task", vim.log.levels.WARN)
        return
    end
    local instruction = operation == "rebase"
        and "Rebase this Task onto its Base branch with `cx rebase`. Resolve any conflicts yourself, then continue it."
        or "Land this Task with `cx land`. Resolve any conflicts yourself, then continue it."
    if item.nvim_socket == vim.v.servername then
        local sent = require("user.cx").rpc({ method = "send", params = { message = instruction } })
        if not sent then
            notify("Task terminal is unavailable", vim.log.levels.ERROR)
            return
        end
    else
        local _, err = run({ "send", item.id, instruction }, { cwd = item.project_scope })
        if err then
            notify(err, vim.log.levels.ERROR)
            return
        end
    end
    attach(item)
end

function M.open(global)
    local items, err = load_items(global)
    if not items then
        notify(err, vim.log.levels.ERROR)
        return
    end

    local lazy_ok, lazy = pcall(require, "lazy")
    if lazy_ok then
        lazy.load({ plugins = { "telescope.nvim" } })
    end
    local ok, pickers = pcall(require, "telescope.pickers")
    if not ok then
        notify("Telescope is unavailable", vim.log.levels.ERROR)
        return
    end
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local function selected()
        local entry = action_state.get_selected_entry()
        return entry and entry.value or nil
    end

    pickers.new(require("telescope.themes").get_ivy({
        layout_config = { height = 22, preview_width = 0.5 },
    }), {
        prompt_title = global and "cx Projects · g: current Project" or "cx Tasks · g: all Projects",
        finder = finders.new_table({
            results = items,
            entry_maker = function(item)
                local state = item.attached and "attached" or "detached"
                return {
                    value = item,
                    ordinal = table.concat({ item.project_scope, item.message, item.branch, item.status, state }, " "),
                    display = string.format(
                        "%-12s %-8s %-22s %-25s %-9s %s",
                        vim.fn.fnamemodify(item.project_scope, ":t"),
                        item.kind,
                        item.message,
                        item.branch,
                        item.status,
                        state
                    ),
                }
            end,
        }),
        sorter = root_pinned_sorter(),
        previewer = previewer(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local item = selected()
                if item then
                    actions.close(prompt_bufnr)
                    vim.schedule(function() attach(item) end)
                end
            end)
            local function action(key, callback)
                local function invoke()
                    local item = selected()
                    if item then
                        actions.close(prompt_bufnr)
                        vim.schedule(function() callback(item) end)
                    end
                end
                map("n", key, invoke)
                return invoke
            end
            local toggle_global = action("g", function() M.open(not global) end)
            map("i", "<C-g>", toggle_global)
            action("d", open_diff)
            action("s", prompt_send)
            action("r", function(item) ask_and_attach(item, "rebase") end)
            action("l", function(item) ask_and_attach(item, "land") end)
            action("x", function(item)
                run_action(item, { "remove", item.id }, function() M.open(global) end)
            end)
            return true
        end,
    }):find()
end

return M
