-- Leader key mapping
vim.g.mapleader = ' '

-- Sets relative numbers for Netrw
vim.g.netrw_bufsettings = "noma nomod nonu nobl nowrap ro rnu"

-- remember the cwd when nvim started (the "root" you want netrw to reset to)
local initial_cwd = vim.fn.getcwd()

-- ensure netrw doesn't auto-change the global cwd while browsing
vim.g.netrw_keepdir = 1

-- when entering a netrw buffer, reset global cwd to the initial root
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    -- safe cd back to initial root
    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(initial_cwd))
  end,
})

-- when entering any regular file buffer, cd to that file's directory
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)

    -- ignore unnamed buffers (no file), directories, and special buffers
    if name == "" then return end
    if vim.fn.isdirectory(name) == 1 then return end

    local ok, ft = pcall(vim.api.nvim_buf_get_option, buf, "filetype")
    if not ok then return end
    if ft == "netrw" or ft == "terminal" or ft == "help" then return end

    -- cd globally to the file's directory
    local dir = vim.fn.fnamemodify(name, ":p:h")
    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(dir))
  end,
})

-- Copy and paste functionality
vim.cmd('vnoremap <C-c> "+y')
vim.cmd('map <C-v> "+p')

-- Opening Netrw
vim.keymap.set('n', '<leader>e', vim.cmd.Ex)

-- Disable default mappings
vim.keymap.set('n', "Q", "<nop>")
vim.api.nvim_set_keymap('t', '<C-q>', '<Nop>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-q>', '<Nop>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<C-q>', '<Nop>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('x', '<C-q>', '<Nop>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('o', '<C-q>', '<Nop>', { noremap = true, silent = true })

-- Opening shell instance on the edited directory (whole screen)
_G.cd_and_open_term = function()
    local original_dir = vim.fn.getcwd()
    vim.cmd('cd %:p:h')
    vim.cmd('term')

    vim.cmd('autocmd TermClose * ++once lua vim.cmd("cd ' .. original_dir .. '")')
end

-- Opening shell instance on the edited directory (split screen)
_G.cd_and_open_term_mod = function()
    local original_win = vim.api.nvim_get_current_win()
    local original_dir = vim.fn.getcwd()

    vim.cmd('lcd %:p:h')
    vim.cmd('vsplit')
    vim.cmd('term')

    local new_win = vim.api.nvim_get_current_win()
    local term_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_current_win(original_win)
    vim.cmd('lcd ' .. original_dir)
    vim.api.nvim_set_current_win(new_win)

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = term_bufnr,  -- Limit to the terminal buffer
        once = true,          -- Run only once
        callback = function()
            if vim.api.nvim_win_is_valid(new_win) then
                vim.api.nvim_set_current_win(new_win)
            end
        end,
    })
end

-- Calls the function to open a new shell instance in a whole window
vim.api.nvim_set_keymap('n', 'Q', ':lua cd_and_open_term()<CR>', { noremap = true, silent = true })

-- Sets new splits for the right side
vim.opt.splitright = true

-- Calls the function to open a new shell instance in a split window
vim.api.nvim_set_keymap('n', '<leader>q', ':lua _G.cd_and_open_term_mod()<CR>', { noremap = true, silent = true })

-- Autocompletion key to exit the terminal automatically
vim.api.nvim_set_keymap('t', '<C-q>', [[<C-\><C-n>i exit<CR>]], { noremap = true, silent = true })

-- Opens a new tab in Newtr in the edited directory
_G.open_netrw_in_file_dir = function()
    local original_file_dir = vim.fn.expand('%:p:h')
    local original_dir = vim.fn.getcwd()

    vim.cmd('tabnew')
    vim.cmd('lcd ' .. original_file_dir)
    vim.cmd('Explore')
    vim.cmd('lcd ' .. original_dir)
    vim.cmd('autocmd TabLeave * ++once lua vim.cmd("lcd ' .. original_dir .. '")')
end

-- Calls the funciton to open a new tab with Newtr on the working directory
vim.api.nvim_set_keymap('n', '<leader>w', ':lua _G.open_netrw_in_file_dir()<CR>', { noremap = true, silent = true })

-- Cycling between numerous tabs
vim.api.nvim_set_keymap('n', 'A', ':tabnext<CR>', { noremap = true, silent = true })

-- Commands to shorten Vim editor writing and exits
vim.api.nvim_set_keymap('n', 'ZC', ':q<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'ZX', ':q!<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'ZA', ':w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'Ñ', ':w<CR>', { noremap = true, silent = true })

-- Command to run latex compilation
vim.api.nvim_set_keymap('n', 'L', ':Latex<CR>', { noremap = true, silent = true })

-- Visual block shifting with indentation
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Commands for cycling split selection with the new split screen shell instance
vim.api.nvim_set_keymap('n', '<S-CR>', '<C-w>w', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<S-CR>', '<C-\\><C-n><C-w>w', { noremap = true, silent = true })

-- Remap for auto suggestions (dropdown autocompletion)
vim.api.nvim_set_keymap('i', '<C-S>', '<C-n>', { noremap = true, silent = true })

-- Remap for s acting as an entry to insert mode
vim.api.nvim_set_keymap('n', 'x', 's', { noremap = true })

-- Remap for s acting as an entry to insert mode
vim.api.nvim_set_keymap('n', 's', 'i', { noremap = true })

-- Remap for using option delete for deleting words
vim.api.nvim_set_keymap('i', '<M-BS>', '<C-W>', { noremap = true, silent = true })

-- Remap for clearing search highlighting
vim.keymap.set('n', '<leader><space>', ':nohlsearch<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<esc>', ':nohlsearch<CR>', { noremap = true, silent = true })

-- Terminal remappings for facilitated use
vim.api.nvim_set_keymap('t', '<Esc>', '<C-\\><C-N>', { noremap = true, silent = true })

-- Visual line movement
vim.keymap.set("n", "<Down>", "gj", { noremap = true })
vim.keymap.set("n", "<Up>", "gk", { noremap = true })

-- Visual line movement for insert mode
vim.keymap.set("i", "<Down>", [[<C-o>gj]])
vim.keymap.set("i", "<Up>", [[<C-o>gk]])
