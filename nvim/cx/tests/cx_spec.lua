local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":p:h:h")
vim.opt.runtimepath:prepend(root)

local cx = require("user.cx")
local menu = require("user.cx.menu")
assert(type(cx.setup) == "function")
assert(type(cx.bootstrap_task) == "function")
assert(type(cx.rpc) == "function")
assert(type(menu.open) == "function")

cx.setup()
local mapping = vim.fn.maparg("<C-i>", "n", false, true)
assert(type(mapping) == "table" and mapping.desc == "Open cx Tasks")
assert(vim.fn.maparg("<C-i>", "t") == "")

local context = cx.rpc({ method = "context" })
assert(type(context.nvim_pid) == "number" and context.nvim_pid > 0)
assert(type(context.cwd) == "string")

local snapshot = cx.rpc({ method = "snapshot" })
assert(snapshot.healthy == true)

local ok = pcall(cx.rpc, { method = "not-a-method" })
assert(ok == false)
