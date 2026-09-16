local M = {}

local task_buffer
local task_job

local function running(job)
    if type(job) ~= "number" or job <= 0 then
        return false
    end
    return vim.fn.jobwait({ job }, 0)[1] == -1
end

function M.bootstrap()
    local thread = vim.env.CX_CODEX_THREAD_ID
    local server = vim.env.CX_APP_SERVER
    local scope = vim.env.CX_SCOPE_ROOT
    if not thread or thread == "" or not server or server == "" or not scope or scope == "" then
        error("Task Neovim is missing cx runtime metadata")
    end

    vim.cmd("silent! only")
    vim.cmd("enew")
    task_buffer = vim.api.nvim_get_current_buf()
    vim.bo[task_buffer].bufhidden = "hide"
    vim.bo[task_buffer].swapfile = false
    vim.api.nvim_buf_set_name(task_buffer, "cx://task/" .. vim.env.CX_TASK_ID)

    task_job = vim.fn.termopen({
        "codex",
        "resume",
        thread,
        "--remote",
        server,
        "-C",
        scope,
    }, {
        cwd = scope,
        on_exit = function(_, code)
            vim.schedule(function()
                vim.notify("Task Codex exited with status " .. code, vim.log.levels.WARN, { title = "cx" })
            end)
        end,
    })
    if task_job <= 0 then
        error("could not start Task Codex")
    end

    vim.api.nvim_create_autocmd("UIEnter", {
        callback = function()
            if vim.api.nvim_buf_is_valid(task_buffer) then
                vim.api.nvim_set_current_buf(task_buffer)
                vim.cmd("startinsert")
            end
        end,
    })
    return true
end

function M.healthy()
    return task_buffer ~= nil
        and vim.api.nvim_buf_is_valid(task_buffer)
        and running(task_job)
end

function M.send(message)
    if type(message) ~= "string" or message == "" or not M.healthy() then
        return false
    end
    vim.api.nvim_chan_send(task_job, message .. "\r")
    return true
end

return M
