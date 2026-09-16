local M = {}

local function terminal_job()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].buftype ~= "terminal" then
        return 0
    end
    local job = vim.b[bufnr].terminal_job_id
    if type(job) ~= "number" then
        return 0
    end
    local pid = vim.fn.jobpid(job)
    return type(pid) == "number" and pid or 0
end

local function tui_count()
    local count = 0
    for _, ui in ipairs(vim.api.nvim_list_uis()) do
        local ok, info = pcall(vim.api.nvim_get_chan_info, ui.chan)
        if ok and type(info.client) == "table" and info.client.name == "nvim-tui" then
            count = count + 1
        end
    end
    return count
end

local function rpc_lua(socket, code, args)
    local ok, channel = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
    if not ok or type(channel) ~= "number" or channel <= 0 then
        return false, "connection failed"
    end
    local request_ok, result = pcall(vim.rpcrequest, channel, "nvim_exec_lua", code, args or {})
    pcall(vim.fn.chanclose, channel)
    return request_ok, result
end

local handlers = {}

function handlers.context()
    return {
        socket = vim.v.servername,
        cwd = vim.fn.getcwd(),
        buftype = vim.bo.buftype,
        job_pid = terminal_job(),
        nvim_pid = vim.fn.getpid(),
        has_ui = tui_count() > 0,
    }
end

function handlers.snapshot()
    local healthy = true
    if vim.env.CX_TASK_ID and vim.env.CX_TASK_ID ~= "" then
        healthy = require("user.cx.terminal").healthy()
    end
    return {
        socket = vim.v.servername,
        pid = vim.fn.getpid(),
        cwd = vim.fn.getcwd(),
        ui_count = tui_count(),
        healthy = healthy,
    }
end

function handlers.preview()
    local ok, snapshot = pcall(function()
        return require("user.nmux").snapshot()
    end)
    return ok and snapshot or handlers.snapshot()
end

function handlers.adopt(params)
    return require("user.nmux").adopt(params.handoff_file)
end

function handlers.handoff(params)
    local handoff = vim.g.nmux_handoff_file or vim.env.NMUX_HANDOFF_FILE
    if type(handoff) ~= "string" or handoff == "" then
        return false
    end
    local alive, adopted = rpc_lua(params.socket, [[return require("user.nmux").adopt(...)]], { handoff })
    if not alive or adopted ~= true then
        return false
    end
    local wrote = pcall(vim.fn.writefile, { params.socket }, handoff)
    if not wrote then
        return false
    end
    vim.schedule(function()
        pcall(vim.api.nvim__redraw, { flush = true })
        pcall(vim.cmd, "detach")
    end)
    return true
end

function handlers.send(params)
    return require("user.cx.terminal").send(params.message)
end

function M.dispatch(request)
    if type(request) ~= "table" or type(request.method) ~= "string" then
        error("invalid cx RPC request")
    end
    local handler = handlers[request.method]
    if not handler then
        error("unknown cx RPC method: " .. request.method)
    end
    return handler(request.params or {})
end

return M
