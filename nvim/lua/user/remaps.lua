-- Copy-paste functionality
vim.keymap.set('n', '<C-c>', '<Plug>OSCYankOperator')
vim.keymap.set('v', '<C-c>', '<Plug>OSCYankVisual')

-- Cycling between numerous tabs
vim.api.nvim_set_keymap('n', 'A', ':tabnext<CR>', { noremap = true, silent = true })

-- Commands to shorten Vim editor writing and exits
vim.api.nvim_set_keymap('n', 'ZC', ':q<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'ZX', ':q!<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'ZA', ':w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'Ñ', ':w<CR>', { noremap = true, silent = true })

-- Visual block shifting with indentation
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Remap for auto suggestions (dropdown autocompletion)
vim.api.nvim_set_keymap('i', 'S>', '<C-n>', { noremap = true, silent = true })

-- Remap for s acting as an entry to insert mode
vim.api.nvim_set_keymap('n', 'x', 's', { noremap = true })

-- Remap for s acting as an entry to insert mode
vim.api.nvim_set_keymap('n', 's', 'i', { noremap = true })

-- Remap for using option delete for deleting words
vim.api.nvim_set_keymap('i', '<M-BS>', '<C-w>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<M-BS>', '<C-w>', { noremap = true, silent = true })

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

-- Closing memento with esc
vim.api.nvim_create_autocmd("FileType", {
    pattern = "memento",
    callback = function(ev)
        vim.keymap.set("n", "<Esc>", function()
            require("memento").toggle()
        end, { buffer = ev.buf, silent = true, desc = "Close Memento" })
    end,
})

-- Unmapping C-e
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    pcall(vim.keymap.del, "n", "<C-e>")
    vim.keymap.set("n", "<C-e>", function()
      require("harpoon.ui").toggle_quick_menu()
    end, { desc = "Harpoon: quick menu", noremap = true, silent = true })
  end,
})

-- Custom escape for nested neovim instanc
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', {noremap = true, silent = true})

