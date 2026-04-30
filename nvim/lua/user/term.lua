-- Opening shell whole screen
_G.cd_and_open_term = function()
    local original_dir = vim.fn.getcwd()
    vim.cmd('cd %:p:h')
    vim.cmd('term')

    vim.cmd('autocmd TermClose * ++once lua vim.cmd("cd ' .. original_dir .. '")')
end

local function is_dir(path)
    return path and path ~= "" and vim.fn.isdirectory(path) == 1
end

local function terminal_cwd(bufnr)
    if vim.bo[bufnr].buftype ~= "terminal" then
        return nil
    end

    local job_id = vim.b[bufnr].terminal_job_id
    if job_id then
        local pid = vim.fn.jobpid(job_id)
        if type(pid) == "number" and pid > 0 then
            local uv = vim.uv or vim.loop
            local ok, cwd = pcall(uv.fs_realpath, "/proc/" .. pid .. "/cwd")
            if ok and is_dir(cwd) then
                return cwd
            end

            if vim.fn.executable("lsof") == 1 then
                ok, cwd = pcall(vim.fn.systemlist, { "lsof", "-a", "-p", tostring(pid), "-d", "cwd", "-Fn" })
                if ok and vim.v.shell_error == 0 then
                    for _, line in ipairs(cwd) do
                        local dir = line:match("^n(.+)$")
                        if is_dir(dir) then
                            return dir
                        end
                    end
                end
            end
        end
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    local launch_dir = name:match("^term://(.-)//%d+:")
    if is_dir(launch_dir) then
        return launch_dir
    end

    return nil
end

local function current_buffer_dir()
    local bufnr = vim.api.nvim_get_current_buf()
    local cwd = terminal_cwd(bufnr)
    if is_dir(cwd) then
        return cwd
    end

    local file_dir = vim.fn.expand("%:p:h")
    if is_dir(file_dir) then
        return file_dir
    end

    return vim.fn.getcwd()
end

local function open_term_vsplit(opts)
    opts = opts or {}

    local original_win = vim.api.nvim_get_current_win()
    local original_dir = vim.fn.getcwd()
    local term_dir = opts.cwd or current_buffer_dir()

    vim.cmd('lcd ' .. vim.fn.fnameescape(term_dir))
    vim.cmd('vsplit')
    vim.cmd('term')

    local new_win = vim.api.nvim_get_current_win()
    local term_bufnr = vim.api.nvim_get_current_buf()
    local job_id = vim.b[term_bufnr].terminal_job_id

    if opts.cmd and job_id then
        vim.api.nvim_chan_send(job_id, opts.cmd .. "\n")
    end

    if vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
        vim.cmd('lcd ' .. vim.fn.fnameescape(original_dir))
        vim.api.nvim_set_current_win(new_win)
    end

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = term_bufnr,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(new_win) then
                vim.api.nvim_set_current_win(new_win)
            end
        end,
    })

    return term_bufnr, new_win
end

-- Opening shell split screen
_G.cd_and_open_term_mod = function()
    return open_term_vsplit()
end

_G.run_in_term_vsplit = function(cmd, cwd)
    return open_term_vsplit({ cmd = cmd, cwd = cwd })
end

vim.api.nvim_set_keymap('n', 'Q', ':lua cd_and_open_term()<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<leader>q', ':lua _G.cd_and_open_term_mod()<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('t', '<C-q>', [[<C-\><C-n>i exit<CR>]], { noremap = true, silent = true })

-- Commands for cycling split selection with the new split screen shell instance
vim.api.nvim_set_keymap('n', '<S-CR>', '<C-w>w', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<S-CR>', '<C-\\><C-n><C-w>w', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<M-S-CR>', '<C-w>W', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<M-S-CR>', '<C-\\><C-n><C-w>W', { noremap = true, silent = true })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(args)
        vim.schedule(function()
            pcall(vim.keymap.del, "n", "<S-CR>", { buffer = args.buf })
            pcall(vim.keymap.del, "n", "<M-S-CR>", { buffer = args.buf })

            vim.keymap.set("n", "<S-CR>", "<C-w>w", {
                buffer = args.buf,
                noremap = true,
                silent = true,
            })

            vim.keymap.set("n", "<M-S-CR>", "<C-w>W", {
                buffer = args.buf,
                noremap = true,
                silent = true,
            })
        end)
    end,
})


-- Skips unnecesary terminal instance closing sequence
vim.api.nvim_create_autocmd("TermClose", {
    pattern = "*",
    callback = function(args)
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
                local success, err = pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
                if not success then
                    vim.notify("Error deleting buffer: " .. err, vim.log.levels.ERROR)
                end
            end
        end)
    end,
})
