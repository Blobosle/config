local maximized_tabs = {}

local function refresh_terminal_window(win)
    vim.schedule(function()
        if not vim.api.nvim_win_is_valid(win) then
            return
        end

        local bufnr = vim.api.nvim_win_get_buf(win)
        local job_id = vim.b[bufnr].terminal_job_id

        if vim.bo[bufnr].buftype == "terminal" and job_id then
            pcall(
                vim.fn.jobresize,
                job_id,
                vim.api.nvim_win_get_width(win),
                vim.api.nvim_win_get_height(win)
            )
        end

        vim.cmd("redraw!")
    end)
end

vim.keymap.set("n", "M", function()
    local tab = vim.api.nvim_get_current_tabpage()
    local state = maximized_tabs[tab]

    if state then
        if vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_buf_is_valid(state.buf) then
            vim.api.nvim_win_set_buf(state.win, state.buf)
        end

        maximized_tabs[tab] = nil
        vim.cmd("tabclose")
        refresh_terminal_window(state.win)
        return
    end

    local origin_win = vim.api.nvim_get_current_win()
    local origin_buf = vim.api.nvim_get_current_buf()
    local placeholder = vim.api.nvim_create_buf(false, true)

    vim.bo[placeholder].bufhidden = "wipe"
    vim.cmd("tab split")
    tab = vim.api.nvim_get_current_tabpage()
    maximized_tabs[tab] = { win = origin_win, buf = origin_buf }
    vim.t.split_maximized = true
    vim.api.nvim_win_set_buf(origin_win, placeholder)
    refresh_terminal_window(vim.api.nvim_get_current_win())
end, { desc = "Toggle maximize split" })
