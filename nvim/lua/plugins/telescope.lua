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

local function find_files_with_parent()
    local cwd = buf_dir()
    local parent = vim.fn.fnamemodify(cwd, ':h')
    local current_finder_key = cwd
    local command = find_command()
    local picker

    local function prompt_targets_parent(prompt)
        return prompt:sub(1, 2) == '..'
    end

    local function prompt_without_parent(prompt)
        if prompt:match('^%.%./') then
            return prompt:gsub('^%.%./', '', 1)
        end
        if prompt:sub(1, 2) == '..' then
            return prompt:sub(3)
        end
        return prompt
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

            local next_finder_key = prompt_targets_parent(prompt) and parent or cwd
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
