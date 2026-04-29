-- Split screen remap
vim.keymap.set('n', 'S', ':vs<CR>', { noremap = true, silent = true })
vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(ev)
        vim.keymap.set('n', 'S', '<Cmd>vsplit<CR>', {
            buffer = ev.buf,
            noremap = true,
            silent = true,
        })
        vim.keymap.set('n', '<leader>g', '<Nop>', {
            buffer = ev.buf,
            noremap = true,
            silent = true,
        })
    end,
})

-- Floating preview for LSP errors
vim.keymap.set("n", "<leader>r", function()
  vim.schedule(function()
    local d = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
    if #d == 0 then
      print("No diagnostics on this line")
      return
    end

    local lines = {}
    for _, x in ipairs(d) do
      table.insert(lines, x.message)
    end

    vim.lsp.util.open_floating_preview(lines, "plaintext", {
      border = "rounded",
      focusable = true,
      close_events = {},
    })
  end)
end, { desc = "Show line diagnostics" })

-- Copy-paste functionality
local mark_oscyank = '<Cmd>lua vim.g.user_oscyank_pending = true<CR>'
vim.keymap.set('n', '<C-c>', mark_oscyank .. '<Plug>OSCYankOperator', { remap = true, silent = true })
vim.keymap.set('v', '<C-c>', mark_oscyank .. '<Plug>OSCYankVisual', { remap = true, silent = true })

-- Cycling between numerous tabs
vim.api.nvim_set_keymap('n', 'A', ':tabnext<CR>', { noremap = true, silent = true })

-- Shift tab
vim.keymap.set("i", "<S-Tab>", function()
  return vim.api.nvim_replace_termcodes("<Esc>==gi", true, false, true)
end, { expr = true, noremap = true, silent = true })

-- C style make vim command setup
vim.opt.makeprg = "gcc %:S && ./a.out"

-- Commands to shorten Vim editor writing and exits
vim.api.nvim_set_keymap('n', 'ZC', ':q<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'ZX', ':q!<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'ZA', '<Cmd>silent write<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'Ñ', '<Cmd>silent write<CR>', { noremap = true, silent = true })
vim.api.nvim_create_user_command("W", "w", {})

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
      if _G.harpoon_menu_from_root then
        return _G.harpoon_menu_from_root()
      end

      local prev = vim.fn.getcwd()
      pcall(vim.cmd, "cd " .. vim.fn.fnameescape(_G.ROOT_CWD or prev))
      require("harpoon.ui").toggle_quick_menu()
      pcall(vim.cmd, "cd " .. vim.fn.fnameescape(prev))
    end, { desc = "Harpoon: quick menu", noremap = true, silent = true })
  end,
})

-- Custom escape for nested neovim instanc
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', {noremap = true, silent = true})
