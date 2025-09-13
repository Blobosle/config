return {
    "ojroques/vim-oscyank",

    config = function()
        vim.keymap.set('n', '<C-c>', '<Plug>OSCYankOperator')
        vim.keymap.set('v', '<C-c>', '<Plug>OSCYankVisual')
    end,
}

