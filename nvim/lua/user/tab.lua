local function tab_label(tabnr)
    local win = vim.fn.tabpagewinnr(tabnr)
    local buflist = vim.fn.tabpagebuflist(tabnr)
    local bufnr = buflist[win]

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        local dir = vim.b[bufnr].netrw_curdir
        if vim.bo[bufnr].filetype == "netrw" and dir == vim.fn.expand("~") then
            return "~"
        end

        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" then
            return vim.fn.fnamemodify(name, ":t")
        end
    end

    return "[No Name]"
end

function _G.UserTabLine()
    local parts = {}

    for tabnr = 1, vim.fn.tabpagenr("$") do
        local is_current = tabnr == vim.fn.tabpagenr()
        table.insert(parts, "%" .. tabnr .. "T")
        table.insert(parts, is_current and "%#TabLineSel#" or "%#TabLine#")
        table.insert(parts, " " .. tab_label(tabnr) .. " ")
    end

    table.insert(parts, "%#TabLineFill#%T")
    return table.concat(parts)
end

vim.o.tabline = "%!v:lua.UserTabLine()"
