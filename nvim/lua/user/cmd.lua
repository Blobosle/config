local cmdwin_preview = require("user.searchreplace")

cmdwin_preview.setup()

vim.keymap.set({'v', 'n'}, ';', ':', { noremap = true })
vim.keymap.set('n', ':', function()
    return cmdwin_preview.keys()
end, { expr = true, noremap = true, silent = true })
vim.keymap.set('n', '_', function()
    return cmdwin_preview.keys("Sh ")
end, { expr = true, noremap = true, silent = true })

vim.keymap.set('x', '_', function()
    return cmdwin_preview.visual_keys("ShR ")
end, { expr = true, noremap = true, silent = true })

vim.keymap.set('x', ':', function()
    return cmdwin_preview.visual_keys()
end, { expr = true, noremap = true, silent = true })

local grp = vim.api.nvim_create_augroup('CmdwinEscQuit', { clear = true })
vim.api.nvim_create_autocmd('CmdwinEnter', {
    group = grp,
    callback = function()
        vim.wo.number = true
        vim.wo.relativenumber = true
        vim.wo.numberwidth = 1
        vim.wo.signcolumn = 'no'
        vim.wo.foldcolumn = '0'
        vim.wo.statuscolumn = '%{v:relnum?v:relnum:v:lnum}  '
        vim.keymap.set('n', '<Esc>', '<Cmd>q<CR>', { buffer = true, silent = true, desc = 'Close cmdwin' })
    end,
})

-- STREAMER (ANSI-capable via nvim_open_term) ----------------------------
local function sh_stream_in_split(cmd, opts)
    opts = opts or {}
    local title  = opts.title or ("[shell] " .. cmd)
    local cwd    = opts.cwd
    local env    = opts.env
    local height = opts.height
    local follow_enabled = opts.follow ~= false
    local stdin_lines = opts.stdin_lines

    cmd = cmd:gsub("^%s*[!$]", "")


    local function infer_netrw_cwd()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "netrw" then

            local dir = vim.b[buf].netrw_curdir or vim.g.netrw_curdir
            if type(dir) == "string" and dir ~= "" then
                return dir
            end
        end
        return nil
    end
    local inferred_netrw_cwd = (cwd == nil) and infer_netrw_cwd() or nil
    cwd = cwd or inferred_netrw_cwd

    vim.cmd("belowright new")
    if height and tonumber(height) then
        vim.cmd(("resize %d"):format(tonumber(height)))
    end

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()


    if inferred_netrw_cwd then

        vim.cmd("lcd " .. vim.fn.fnameescape(inferred_netrw_cwd))
    end

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = opts.filetype or "log"
    vim.api.nvim_buf_set_name(buf, title)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    local term_chan = vim.api.nvim_open_term(buf, {})

    local function at_bottom_in_output_win()
        if not vim.api.nvim_win_is_valid(win) then return false end
        return vim.api.nvim_win_call(win, function()
            return vim.fn.line("w$") == vim.fn.line("$")
        end)
    end

    local pending = ""
    local function add_lines(lines, prefix, suffix)
        if not lines or (#lines == 1 and lines[1] == "") then return end
        local t = {}
        for _, l in ipairs(lines) do
            if l ~= "" then
                local line = l
                if prefix then
                    line = prefix .. line
                end
                if suffix then
                    line = line .. suffix
                end
                table.insert(t, line)
            end
        end
        if #t > 0 then
            pending = pending .. table.concat(t, "\r\n") .. "\r\n"
        end
    end

    local timer = vim.loop.new_timer()
    local function flush()
        if pending == "" or not vim.api.nvim_buf_is_valid(buf) then return end
        local follow = follow_enabled and at_bottom_in_output_win()

        pcall(vim.api.nvim_chan_send, term_chan, pending)
        pending = ""
        if follow and vim.api.nvim_win_is_valid(win) then
            local last = vim.api.nvim_buf_line_count(buf)
            pcall(vim.api.nvim_win_set_cursor, win, { last, 0 })
        end
    end
    timer:start(50, 50, vim.schedule_wrap(flush))

    local aug = vim.api.nvim_create_augroup("ShStream_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
        group = aug, buffer = buf,
        callback = function()
            if timer and not timer:is_closing() then timer:stop(); timer:close() end
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = aug,
        callback = function(args)
            if tonumber(args.match) == win then
                if timer and not timer:is_closing() then timer:stop(); timer:close() end
            end
        end,
    })

    add_lines({ "$ " .. cmd, "" })

    local shell = (vim.o.shell ~= "" and vim.o.shell) or os.getenv("SHELL") or "sh"
    local job_env = vim.tbl_extend("force", {}, env or {})
    if job_env.TERM == nil or job_env.TERM == "" or job_env.TERM == "dumb" then
        job_env.TERM = "xterm-256color"
    end
    job_env.COLORTERM = job_env.COLORTERM or "truecolor"
    job_env.CLICOLOR = job_env.CLICOLOR or "1"
    job_env.CLICOLOR_FORCE = job_env.CLICOLOR_FORCE or "1"
    job_env.FORCE_COLOR = job_env.FORCE_COLOR or "1"

    local job_id = vim.fn.jobstart({ shell, "-c", cmd }, {
        cwd = cwd,
        env = job_env,
        stdout_buffered = false,
        stderr_buffered = false,
        pty = false,
        stdin = "pipe",
        on_stdout = vim.schedule_wrap(function(_, data) add_lines(data) end),
        on_stderr = vim.schedule_wrap(function(_, data) add_lines(data, "\27[31m", "\27[0m") end),
        on_exit   = vim.schedule_wrap(function(_, code)
            add_lines({ "", ("[exit %d]"):format(code) })
            flush()
            if timer and not timer:is_closing() then timer:stop(); timer:close() end
            if opts.readonly_on_exit and vim.api.nvim_buf_is_valid(buf) then
                vim.bo[buf].modifiable = false
            end
        end),
    })

    if job_id <= 0 then
        pcall(vim.api.nvim_chan_send, term_chan,
            "Failed to start job: " .. cmd .. "\r\n" ..
            "TIP: try full path (e.g. ~/bin/mycmd) or check your shell rc.\r\n")
        if timer and not timer:is_closing() then timer:stop(); timer:close() end
        return
    end

    if stdin_lines and #stdin_lines > 0 then
        vim.fn.chansend(job_id, stdin_lines)
        vim.fn.chanclose(job_id, "stdin")
    end
end

local function sh_complete(arglead, cmdline, cursorpos)
    local before_cursor = cmdline:sub(1, cursorpos)
    local args = before_cursor:gsub("^%s*%S+%s*", "")

    if not args:find("%s") then
        return vim.fn.getcompletion(arglead, "shellcmd")
    end

    return vim.fn.getcompletion(arglead, "file")
end

vim.api.nvim_create_user_command("Sh", function(args)
    sh_stream_in_split(args.args, { height = 20 })
end, { nargs = "+", complete = sh_complete })

vim.api.nvim_create_user_command("ShIn", function(args)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    sh_stream_in_split(args.args, { height = 20, stdin_lines = lines })
end, { nargs = "+", complete = sh_complete })

vim.api.nvim_create_user_command("ShR", function(args)
    local l1, l2 = args.line1, args.line2
    local lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
    sh_stream_in_split(args.args, { height = 20, stdin_lines = lines })
end, { nargs = "+", range = true, complete = sh_complete })
