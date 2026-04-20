local function buf_dir()
    local d = vim.fn.expand('%:p:h')
    if d == nil or d == '' then d = vim.fn.getcwd() end
    return d
end

local function find_command()
    if vim.fn.executable('rg') == 1 then
        return { 'rg', '--files', '--color', 'never' }
    end
    if vim.fn.executable('fd') == 1 then
        return { 'fd', '--type', 'f', '--color', 'never' }
    end
    if vim.fn.executable('fdfind') == 1 then
        return { 'fdfind', '--type', 'f', '--color', 'never' }
    end
    if vim.fn.executable('find') == 1 and vim.fn.has('win32') == 0 then
        return { 'find', '.', '-type', 'f' }
    end
    if vim.fn.executable('where') == 1 then
        return { 'where', '/r', '.', '*' }
    end
end

local function file_entry_maker(opts, cwd)
    return require('telescope.make_entry').gen_from_file(vim.tbl_extend('force', opts or {}, {
        cwd = cwd,
    }))
end

local function parent_aware_file_sorter(opts, strip_prompt)
    local sorter = require('telescope.config').values.file_sorter(opts)
    local highlighter = sorter.highlighter

    if highlighter then
        sorter.highlighter = function(_, prompt, display)
            return highlighter(sorter, strip_prompt(prompt), display)
        end
    end

    return sorter
end

local function find_files_with_parent()
    local cwd = buf_dir()
    local current_finder_key = cwd
    local command = find_command()
    local picker

    local function parent_prompt_parts(prompt)
        local levels = 0
        local rest = prompt

        while rest:match('^%.%./') do
            levels = levels + 1
            rest = rest:sub(4)
        end

        if rest == '..' then
            return levels + 1, ''
        end

        if rest:sub(1, 2) == '..' then
            return levels + 1, rest:sub(3)
        end

        return levels, rest
    end

    local function prompt_without_parent(prompt)
        local _, rest = parent_prompt_parts(prompt)
        return rest
    end

    local function prompt_cwd(prompt)
        local levels = parent_prompt_parts(prompt)
        local next_cwd = cwd

        for _ = 1, levels do
            next_cwd = vim.fn.fnamemodify(next_cwd, ':h')
        end

        return next_cwd
    end

    local function update_picker_cwd(next_cwd)
        if picker then
            picker.cwd = next_cwd
        end
    end

    local opts = {
        cwd = cwd,
        attach_mappings = function(prompt_bufnr)
            picker = require('telescope.actions.state').get_current_picker(prompt_bufnr)
            return true
        end,
        on_input_filter_cb = function(prompt)
            if not command then
                return { prompt = prompt }
            end

            local next_finder_key = prompt_cwd(prompt)
            if next_finder_key == current_finder_key then
                return {
                    prompt = prompt_without_parent(prompt),
                }
            end

            current_finder_key = next_finder_key
            update_picker_cwd(next_finder_key)

            return {
                prompt = prompt_without_parent(prompt),
                updated_finder = require('telescope.finders').new_oneshot_job(command, {
                    cwd = next_finder_key,
                    entry_maker = file_entry_maker(opts, next_finder_key),
                }),
            }
        end,
    }

    opts.entry_maker = file_entry_maker(opts, cwd)
    opts.sorter = parent_aware_file_sorter(opts, prompt_without_parent)

    require('telescope.builtin').find_files(opts)
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
                find_files_with_parent()
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
