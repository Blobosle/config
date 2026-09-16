local M = {}

local rpc = require("user.cx.rpc")

function M.setup()
    vim.keymap.set("n", "<C-i>", function()
        require("user.cx.menu").open(false)
    end, {
        noremap = true,
        silent = true,
        desc = "Open cx Tasks",
    })
end

function M.bootstrap_task()
    return require("user.cx.terminal").bootstrap()
end

function M.rpc(request)
    return rpc.dispatch(request)
end

return M
