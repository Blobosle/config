local function buf_dir()
    local d = vim.fn.expand('%:p:h')
    if d == nil or d == '' then d = vim.fn.getcwd() end
    return d
end

local function find_dirs_here()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    local cwd = buf_dir()

    pickers.new({}, {
        prompt_title = "Directories",
        finder = finders.new_oneshot_job({
            "fd",
            "--type", "d",
            "--strip-cwd-prefix",

            "--exclude", "node_modules",
            "--exclude", ".git",

            ".",
        }, {
            cwd = cwd,
        }),
        sorter = conf.generic_sorter({}),
    }):find()
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

        { "<leader>f", function()
                find_dirs_here()
            end,
            desc = "Telescope find directories (here)"
        },
    },
}
