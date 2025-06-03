local builtin = require("telescope.builtin")

-- Only load in current directory

_G.cd_and_open_telescope = function()
    local original_dir = vim.fn.getcwd()
    vim.cmd('cd %:p:h')
    builtin.find_files()

    vim.cmd('autocmd User TelescopePreviewerLoaded ++once lua vim.cmd("cd ' .. original_dir .. '")')
end

-- Remap to open telescope
vim.api.nvim_set_keymap('n', '<C-f>', ':lua cd_and_open_telescope()<CR>', { noremap = true, silent = true })

-- Remap to open function and objects table lookup
vim.keymap.set('n', '<leader><leader>', function()
    require('telescope.builtin').lsp_document_symbols({
        layout_strategy = 'horizontal',
        layout_config = {
            anchor = 'NE', -- North-East (Top-Right)
            width = 75,   -- 50% of the screen width
            height = 15,  -- 30% of the screen height
            preview_width = 0.5 -- Adjust as needed for the preview section
        },
        border = true,   -- Optional: add a border
    })
end, { noremap = true, silent = true })

-- Additional plugin for fzf
require('telescope').load_extension('fzy_native')
