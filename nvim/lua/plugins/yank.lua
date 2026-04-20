return {
    "ojroques/vim-oscyank",

    init = function()
        vim.g.oscyank_silent = 1
    end,

    config = function()
        local mark_oscyank = '<Cmd>lua vim.g.user_oscyank_pending = true<CR>'

        vim.keymap.set('n', '<C-c>', mark_oscyank .. '<Plug>OSCYankOperator', { remap = true, silent = true })
        vim.keymap.set('v', '<C-c>', mark_oscyank .. '<Plug>OSCYankVisual', { remap = true, silent = true })

        vim.api.nvim_create_autocmd('TextYankPost', {
            group = vim.api.nvim_create_augroup('UserOSCYankMessage', { clear = true }),
            callback = function()
                if not vim.g.user_oscyank_pending then
                    return
                end

                vim.g.user_oscyank_pending = false
                local text = vim.fn.getreg('"')
                if vim.g.oscyank_trim ~= nil and vim.g.oscyank_trim ~= 0 then
                    text = vim.trim(text)
                end

                local show = _G.UserShowTopMessage
                if type(show) == 'function' then
                    show(string.format('[oscyank] %d characters copied', #text))
                end
            end,
        })
    end,
}
