local ns = vim.api.nvim_create_namespace("user.eof")
local aug = vim.api.nvim_create_augroup("UserEofLineCount", { clear = true })

local function should_render(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    if vim.bo[buf].buftype ~= "" then
        return false
    end

    if vim.bo[buf].filetype == "netrw" then
        return false
    end

    return vim.bo[buf].modifiable or vim.bo[buf].readonly
end

local function render(buf)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    if not should_render(buf) then
        return
    end

    local line_count = vim.api.nvim_buf_line_count(buf)
    local last_line = math.max(line_count - 1, 0)

    vim.api.nvim_buf_set_extmark(buf, ns, last_line, 0, {
        virt_lines = { { { tostring(line_count), "LineNr" } } },
        virt_lines_above = false,
        virt_lines_leftcol = true,
    })
end

vim.api.nvim_create_autocmd({
    "BufEnter",
    "BufWinEnter",
    "TextChanged",
    "TextChangedI",
    "TextChangedP",
    "BufWritePost",
}, {
    group = aug,
    callback = function(ev)
        render(ev.buf)
    end,
})
