vim.keymap.set("n", "M", function()
    local w = vim.api.nvim_win_get_width(0)
    local h = vim.api.nvim_win_get_height(0)

    -- Heuristic: if window is already "big", restore; otherwise maximize.
    -- (This avoids needing global state.)
    local cols = vim.o.columns
    local lines = vim.o.lines

    local is_maximized = (w > math.floor(cols * 0.8)) and (h > math.floor(lines * 0.8))

    if is_maximized then
        vim.cmd("wincmd =")      -- restore
    else
        vim.cmd("wincmd |")      -- maximize width
        vim.cmd("wincmd _")      -- maximize height
    end
end, { desc = "Toggle maximize split" })

