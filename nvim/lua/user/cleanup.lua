local group = vim.api.nvim_create_augroup("user_cleanup_hidden_buffers", { clear = true })

local function is_visible(bufnr)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
            return true
        end
    end

    return false
end

local function should_wipe(bufnr, current)
    if bufnr == current or not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    if not vim.bo[bufnr].buflisted or vim.bo[bufnr].modified then
        return false
    end

    if vim.bo[bufnr].buftype ~= "" then
        return false
    end

    if vim.api.nvim_buf_get_name(bufnr) == "" then
        return false
    end

    return not is_visible(bufnr)
end

local function cleanup_hidden_file_buffers()
    local current = vim.api.nvim_get_current_buf()

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if should_wipe(bufnr, current) then
            pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
        end
    end
end

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = cleanup_hidden_file_buffers,
})
