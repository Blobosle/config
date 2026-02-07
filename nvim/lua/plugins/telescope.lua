local function buf_dir()
    local d = vim.fn.expand('%:p:h')
    if d == nil or d == '' then d = vim.fn.getcwd() end
    return d
end

return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = {
        'nvim-lua/plenary.nvim',
        { "nvim-telescope/telescope-live-grep-args.nvim", version = "^1.0.0" },
    },
    config = function()
        require('telescope').load_extension('live_grep_args')
    end,
    keys = {
        { "<C-f>", function()
                require('telescope.builtin').find_files({ cwd = buf_dir() })
            end,
            desc = "Telescope find files (here)"
        },

        { "<C-g>", function()
                require('telescope').extensions.live_grep_args.live_grep_args({
                    cwd = buf_dir(),
                })
            end,
            desc = "Telescope grep (args) here"
        },
    },
}
