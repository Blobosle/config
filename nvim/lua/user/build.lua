local M = {}

local store_path = vim.fn.stdpath("data") .. "/user-build-commands.json"

local root_markers = {
    ".git",
    "Makefile",
    "makefile",
    "package.json",
    "Cargo.toml",
    "go.mod",
    "CMakeLists.txt",
    "pyproject.toml",
    "compile_commands.json",
}

local function path_sep()
    return package.config:sub(1, 1)
end

local function is_dir(path)
    return path and path ~= "" and vim.fn.isdirectory(path) == 1
end

local function normalize(path)
    if not path or path == "" then
        return vim.loop.cwd()
    end
    path = vim.fn.expand(path)
    local resolved = vim.loop.fs_realpath(path)
    path = resolved or vim.fn.fnamemodify(path, ":p")
    path = path:gsub(path_sep() .. "$", "")
    return path
end

local function starts_with_path(path, root)
    path = normalize(path)
    root = normalize(root)
    return path == root or path:sub(1, #root + 1) == root .. path_sep()
end

local function current_dir()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "terminal" then
        local job_id = vim.b[buf].terminal_job_id
        if job_id then
            local pid = vim.fn.jobpid(job_id)
            if type(pid) == "number" and pid > 0 then
                local uv = vim.uv or vim.loop
                local ok, cwd = pcall(uv.fs_realpath, "/proc/" .. pid .. "/cwd")
                if ok and is_dir(cwd) then
                    return normalize(cwd)
                end

                if vim.fn.executable("lsof") == 1 then
                    ok, cwd = pcall(vim.fn.systemlist, { "lsof", "-a", "-p", tostring(pid), "-d", "cwd", "-Fn" })
                    if ok and vim.v.shell_error == 0 then
                        for _, line in ipairs(cwd) do
                            local dir = line:match("^n(.+)$")
                            if is_dir(dir) then
                                return normalize(dir)
                            end
                        end
                    end
                end
            end
        end

        local name = vim.api.nvim_buf_get_name(buf)
        local launch_dir = name:match("^term://(.-)//%d+:")
        if is_dir(launch_dir) then
            return normalize(launch_dir)
        end
    end

    if vim.bo[buf].filetype == "netrw" then
        local dir = vim.b[buf].netrw_curdir or vim.g.netrw_curdir
        if type(dir) == "string" and dir ~= "" then
            return normalize(dir)
        end
    end

    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" then
        local stat = vim.loop.fs_stat(name)
        if stat and stat.type == "directory" then
            return normalize(name)
        end
        return normalize(vim.fn.fnamemodify(name, ":h"))
    end

    return normalize(vim.loop.cwd())
end

local function guess_root(start)
    start = normalize(start or current_dir())
    local root = vim.fs.root(start, root_markers)
    return normalize(root or start)
end

local function read_store()
    local ok, lines = pcall(vim.fn.readfile, store_path)
    if not ok or not lines or #lines == 0 then
        return { projects = {} }
    end

    local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
    if not ok_decode or type(decoded) ~= "table" then
        return { projects = {} }
    end

    decoded.projects = decoded.projects or {}
    return decoded
end

local function write_store(store)
    local dir = vim.fn.fnamemodify(store_path, ":h")
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile(vim.split(vim.fn.json_encode(store), "\n"), store_path)
end

local function project_commands(project)
    project.commands = project.commands or {}
    return project.commands
end

local function stored_projects_for_dir(store, dir)
    local matches = {}
    for root, project in pairs(store.projects or {}) do
        if starts_with_path(dir, root) and #(project_commands(project)) > 0 then
            table.insert(matches, {
                root = normalize(root),
                project = project,
            })
        end
    end
    table.sort(matches, function(a, b)
        return #a.root > #b.root
    end)
    return matches
end

local function win_size(lines, min_width)
    local max_len = min_width or 48
    for _, line in ipairs(lines) do
        max_len = math.max(max_len, vim.fn.strdisplaywidth(line))
    end
    local width = math.min(math.max(max_len + 4, min_width or 48), math.floor(vim.o.columns * 0.85))
    local height = math.min(math.max(#lines, 1), math.floor(vim.o.lines * 0.65))
    return width, height
end

local function close_win(win)
    if vim.fn.mode():match("[iR]") then
        vim.cmd("stopinsert")
    end
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

local function select_float(title, items, render, on_select)
    if #items == 0 then
        vim.notify("No build commands found", vim.log.levels.INFO)
        return
    end

    local lines = {}
    for i, item in ipairs(items) do
        lines[i] = render(item, i)
    end

    local width, height = win_size(lines, 56)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = height,
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "center",
        style = "minimal",
    })

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.wo[win].cursorline = true

    local function choose()
        local row = vim.api.nvim_win_get_cursor(win)[1]
        local item = items[row]
        close_win(win)
        if item then
            on_select(item)
        end
    end

    vim.keymap.set("n", "<CR>", choose, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", function() close_win(win) end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<Esc>", function() close_win(win) end, { buffer = buf, silent = true })
end

local function input_float(title, prompt, default, on_submit)
    local line = default or ""
    local width = math.min(math.max(vim.fn.strdisplaywidth(line) + 6, vim.fn.strdisplaywidth(prompt) + 4, 64), math.floor(vim.o.columns * 0.85))
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = math.floor((vim.o.lines - 2) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = 2,
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "center",
        style = "minimal",
    })

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prompt, line })
    vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 0, 0, -1)
    vim.wo[win].virtualedit = "onemore"

    local function place_cursor()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_set_cursor(win, { 2, #line + 1 })
        end
    end

    place_cursor()

    local function submit()
        local value = vim.trim(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] or "")
        close_win(win)
        if value ~= "" then
            on_submit(value)
        end
    end

    vim.keymap.set("i", "<CR>", submit, { buffer = buf, silent = true })
    vim.keymap.set("n", "<CR>", submit, { buffer = buf, silent = true })
    vim.keymap.set({ "i", "n" }, "<Esc>", function() close_win(win) end, { buffer = buf, silent = true })
    vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
            vim.cmd("startinsert")
            place_cursor()
        end
    end)
end

local function suggested_command(root)
    if vim.fn.filereadable(root .. "/Makefile") == 1 or vim.fn.filereadable(root .. "/makefile") == 1 then
        return "make"
    end
    if vim.fn.filereadable(root .. "/Cargo.toml") == 1 then
        return "cargo build"
    end
    if vim.fn.filereadable(root .. "/go.mod") == 1 then
        return "go build ./..."
    end
    if vim.fn.filereadable(root .. "/package.json") == 1 then
        return "npm run dev"
    end
    if vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 then
        return "cmake --build build"
    end
    return vim.o.makeprg ~= "" and vim.o.makeprg or ""
end

local function add_command_flow(default_root, on_added)
    input_float("Project Root", "Edit project root", default_root, function(root)
        root = normalize(root)
        input_float("Add Build Command", "Project: " .. root, suggested_command(root), function(command)
            local store = read_store()
            store.projects[root] = store.projects[root] or { commands = {} }
            local commands = project_commands(store.projects[root])
            for _, existing in ipairs(commands) do
                if existing == command then
                    vim.notify("Build command already exists for this project", vim.log.levels.INFO)
                    return
                end
            end
            table.insert(commands, command)
            write_store(store)
            if on_added then
                on_added(root, command)
            else
                vim.notify("Added build command for " .. root, vim.log.levels.INFO)
            end
        end)
    end)
end

local function run_command(root, command)
    root = normalize(root)
    local expanded_command = vim.fn.expandcmd(command)
    local buf = vim.api.nvim_get_current_buf()

    if vim.bo[buf].buftype == "terminal" then
        local job_id = vim.b[buf].terminal_job_id
        if not job_id then
            vim.notify("Current terminal has no job to send the build command to", vim.log.levels.ERROR)
            return
        end

        vim.b[buf].terminal_last_command = expanded_command
        vim.api.nvim_chan_send(job_id, ("cd %s && %s\n"):format(vim.fn.shellescape(root), expanded_command))
        vim.cmd("startinsert")
        return
    end

    local original_win = vim.api.nvim_get_current_win()
    local original_dir = vim.fn.getcwd()

    vim.cmd("lcd " .. vim.fn.fnameescape(root))
    vim.cmd("vsplit")
    vim.cmd("term")

    local new_win = vim.api.nvim_get_current_win()
    buf = vim.api.nvim_get_current_buf()
    local job_id = vim.b[buf].terminal_job_id
    vim.b[buf].terminal_last_command = expanded_command

    if vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
        vim.cmd("lcd " .. vim.fn.fnameescape(original_dir))
        vim.api.nvim_set_current_win(new_win)
    end

    if job_id then
        vim.api.nvim_chan_send(job_id, expanded_command .. "\n")
    end

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(new_win) then
                vim.api.nvim_set_current_win(new_win)
            end
        end,
    })
end

local function with_project_for_run(callback)
    local store = read_store()
    local dir = current_dir()
    local matches = stored_projects_for_dir(store, dir)

    if #matches == 0 then
        add_command_flow(dir, callback)
        return
    end

    local function choose_command(match)
        local commands = project_commands(match.project)
        if #commands == 1 then
            callback(match.root, commands[1])
            return
        end
        select_float("Build Commands", commands, function(command)
            return command
        end, function(command)
            callback(match.root, command)
        end)
    end

    if #matches == 1 then
        choose_command(matches[1])
        return
    end

    select_float("Matching Projects", matches, function(match)
        return match.root
    end, choose_command)
end

function M.run()
    with_project_for_run(run_command)
end

function M.add()
    local root = guess_root(current_dir())
    add_command_flow(root)
end

function M.remove_command()
    local store = read_store()
    local matches = stored_projects_for_dir(store, current_dir())
    if #matches == 0 then
        vim.notify("No build commands for the current project", vim.log.levels.INFO)
        return
    end

    local function choose_command(match)
        select_float("Remove Build Command", project_commands(match.project), function(command)
            return command
        end, function(command)
            local commands = project_commands(match.project)
            for i, existing in ipairs(commands) do
                if existing == command then
                    table.remove(commands, i)
                    break
                end
            end
            if #commands == 0 then
                store.projects[match.root] = nil
            end
            write_store(store)
            vim.notify("Removed build command", vim.log.levels.INFO)
        end)
    end

    if #matches == 1 then
        choose_command(matches[1])
        return
    end

    select_float("Matching Projects", matches, function(match)
        return match.root
    end, choose_command)
end

function M.remove_project()
    local store = read_store()
    local projects = {}
    for root, project in pairs(store.projects or {}) do
        if #(project_commands(project)) > 0 then
            table.insert(projects, normalize(root))
        end
    end
    table.sort(projects)

    select_float("Remove Project Commands", projects, function(root)
        return root
    end, function(root)
        store.projects[root] = nil
        write_store(store)
        vim.notify("Removed all build commands for " .. root, vim.log.levels.INFO)
    end)
end

function M.menu()
    local actions = {
        { label = "Run build command", run = M.run },
        { label = "Add command for current project", run = M.add },
        { label = "Remove command from current project", run = M.remove_command },
        { label = "Remove all commands for any project", run = M.remove_project },
    }

    select_float("Build Menu", actions, function(action)
        return action.label
    end, function(action)
        action.run()
    end)
end

vim.api.nvim_create_user_command("Build", M.menu, {})

vim.keymap.set("n", ",", M.run, { noremap = true, silent = true })
vim.keymap.set("t", ",", [[<C-\><C-n><Cmd>lua require("user.build").run()<CR>]], { noremap = true, silent = true })

return M
