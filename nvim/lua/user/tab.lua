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
    local maximized = {}
    local tabpages = vim.api.nvim_list_tabpages()

    for tabnr = 1, vim.fn.tabpagenr("$") do
        local is_current = tabnr == vim.fn.tabpagenr()
        local label = "%" .. tabnr .. "T"
            .. (is_current and "%#TabLineSel#" or "%#TabLine#")
            .. " " .. tab_label(tabnr) .. " "
        local ok, is_maximized = pcall(vim.api.nvim_tabpage_get_var, tabpages[tabnr], "split_maximized")

        table.insert(ok and is_maximized and maximized or parts, label)
    end

    if #maximized > 0 then
        table.insert(parts, "%#TabLineFill#%=")
        vim.list_extend(parts, maximized)
    end

    table.insert(parts, "%#TabLineFill#%T")
    return table.concat(parts)
end

vim.o.tabline = "%!v:lua.UserTabLine()"
