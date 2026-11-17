local M = {}

local function open_pdf(tex_path)
    local pdf_path = vim.fn.fnamemodify(tex_path, ":p:r") .. ".pdf"
    vim.fn.jobstart({ "open", pdf_path }, { detach = true })
end

local function has_latex_makefile(dir)
    for _, name in ipairs({ "GNUmakefile", "Makefile", "makefile" }) do
        local path = dir .. "/" .. name
        if vim.fn.filereadable(path) == 1 then
            local contents = table.concat(vim.fn.readfile(path), "\n")
            if contents:find("latexmk", 1, true) then
                return true
            end
        end
    end
    return false
end

local function compile_latex(path)
    path = vim.fn.fnamemodify(path or "", ":p")
    if path == "" or vim.fn.fnamemodify(path, ":e") ~= "tex" then
        if _G.UserShowTopMessage then
            _G.UserShowTopMessage("Skipping LaTeX compilation.")
        else
            vim.notify("Skipping LaTeX compilation.", vim.log.levels.WARN)
        end
        return
    end

    local dir = vim.fn.fnamemodify(path, ":h")
    local pdf = vim.fn.fnamemodify(path, ":t:r") .. ".pdf"
    local command
    vim.fn.mkdir(dir .. "/.latex", "p")

    if has_latex_makefile(dir) then
        command = { "make", "--no-print-directory" }
        -- Force the first .latex build if only an older root PDF exists.
        if vim.fn.filereadable(dir .. "/" .. pdf) == 1
            and vim.fn.filereadable(dir .. "/.latex/" .. pdf) ~= 1 then
            table.insert(command, "-B")
        end
        vim.list_extend(command, { "BUILDDIR=.latex", pdf })
    else
        command = {
            "latexmk", "-pdf", "-interaction=nonstopmode", "-silent",
            "-auxdir=.latex", vim.fn.fnamemodify(path, ":t"),
        }
    end

    vim.fn.jobstart(command, {
        cwd = dir,
        on_exit = function(_, code)
            if code == 0 then
                vim.notify("LaTeX build finished", vim.log.levels.INFO)
                vim.schedule(function() open_pdf(path) end)
            else
                vim.notify("LaTeX build failed", vim.log.levels.ERROR)
            end
        end,
    })
end

-- Also shared by the regular terminal split shortcut in user/term.lua.
function M.open_terminal(dir, command)
    local original_win = vim.api.nvim_get_current_win()
    local original_dir = vim.fn.getcwd()

    vim.cmd("lcd " .. vim.fn.fnameescape(dir))
    vim.cmd("vsplit")
    if command then
        -- Run before starting the interactive shell, avoiding startup input echo.
        vim.cmd("enew")
        vim.fn.jobstart({ vim.o.shell, "-c", command .. "; exec " .. vim.fn.shellescape(vim.o.shell) }, {
            term = true,
        })
    else
        vim.cmd("term")
    end

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
        vim.cmd("lcd " .. vim.fn.fnameescape(original_dir))
        vim.api.nvim_set_current_win(win)
    end

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_current_win(win)
            end
        end,
    })
    return buf, win
end

-- Add handlers here in priority order. Return true when the file is handled.
-- Each handler receives the absolute path of a readable file.
local handlers = {
    function(path)
        if vim.fn.fnamemodify(path, ":e"):lower() == "tex" then
            compile_latex(path)
            return true
        end
    end,
    function(path)
        if vim.fn.executable(path) == 1 then
            M.open_terminal(vim.fn.fnamemodify(path, ":h"), vim.fn.shellescape(path))
            return true
        end
    end,
}

local function target_path()
    local name = vim.trim(vim.api.nvim_get_current_line())
    if name == "" or name:match('^"') then
        return nil
    end
    local dir = vim.b.netrw_curdir or vim.fn.getcwd()
    local path = vim.fn.fnamemodify(dir .. "/" .. name, ":p")
    -- Strip netrw's executable marker without stripping a real filename's '*'.
    if name:sub(-1) == "*" and vim.fn.filereadable(path) ~= 1 then
        local executable = path:sub(1, -2)
        if vim.fn.executable(executable) == 1 then
            return executable
        end
    end
    return path
end

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserNetrwX", { clear = true }),
    pattern = "netrw",
    callback = function(ev)
        local original_x = vim.fn.maparg("x", "n", false, true)
        vim.keymap.set("n", "x", function()
            local path = target_path()
            if path and vim.fn.filereadable(path) == 1 then
                for _, handle in ipairs(handlers) do
                    if handle(path) then return end
                end
            end

            if original_x.rhs and original_x.rhs ~= "" then
                local keys = vim.api.nvim_replace_termcodes(original_x.rhs, true, false, true)
                vim.api.nvim_feedkeys(keys, "n", false)
            else
                vim.fn["netrw#BrowseX"](path or vim.fn.expand("<cfile>"), 0)
            end
        end, { buffer = ev.buf, silent = true, desc = "Run or open netrw entry" })
    end,
})

vim.api.nvim_create_user_command("Latex", function()
    compile_latex(vim.fn.expand("%:p"))
end, {})
vim.api.nvim_create_user_command("LTX", "Latex", {})
vim.api.nvim_create_user_command("OpenPDF", function()
    open_pdf(vim.fn.expand("%:p"))
end, {})
vim.keymap.set("n", "L", "<Cmd>Latex<CR>", { noremap = true, silent = true })

return M
