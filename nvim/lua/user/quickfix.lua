local function qf_next_stop()
    local cur = vim.api.nvim_win_get_cursor(0)[1]

    local pipe = vim.fn.search('\\V||', 'W')

    local save = vim.fn.getpos('.')
    local blank = vim.fn.search('^\\s*$', 'W')
    local para = 0
    if blank > 0 then
        vim.fn.cursor(blank, 1)
        para = vim.fn.search('^\\S', 'W')
    end
    vim.fn.setpos('.', save)

    local target = 0
    if pipe > 0 and pipe > cur then target = pipe end
    if para > 0 and para > cur and (target == 0 or para < target) then target = para end

    if target > 0 then
        vim.api.nvim_win_set_cursor(0, { target, 0 })
    else
        vim.cmd('normal! }')
    end
end

local function qf_prev_stop()
    local cur = vim.api.nvim_win_get_cursor(0)[1]

    local pipe = vim.fn.search('\\V||', 'bW')

    local save = vim.fn.getpos('.')
    local prev_blank = vim.fn.search('^\\s*$', 'bW')
    local para = 0
    if prev_blank > 0 then

        vim.fn.cursor(prev_blank, 1)
        para = vim.fn.search('^\\S', 'W')

        if not (para > 0 and para < cur) then para = 0 end
    end
    vim.fn.setpos('.', save)

    local target = 0
    if pipe > 0 and pipe < cur then target = pipe end
    if para > 0 and (target == 0 or para > target) then target = para end

    if target > 0 then
        vim.api.nvim_win_set_cursor(0, { target, 0 })
    else
        vim.cmd('normal! {')
    end
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'qf',
    callback = function()

        vim.keymap.set('n', '}', function()
            local n = vim.v.count1
            for _ = 1, n do qf_next_stop() end
        end, { buffer = true, desc = 'Quickfix paragraph/|| forward' })

        vim.keymap.set('n', '{', function()
            local n = vim.v.count1
            for _ = 1, n do qf_prev_stop() end
        end, { buffer = true, desc = 'Quickfix paragraph/|| backward' })
    end,
})
