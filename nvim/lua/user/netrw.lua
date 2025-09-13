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

-- Netrw relative numbers
vim.g.netrw_bufsettings = "noma nomod nonu nobl nowrap ro rnu"

-- Opening Netrw
vim.keymap.set('n', '<leader>e', vim.cmd.Ex)

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

vim.api.nvim_set_keymap('n', '<leader>w', ':lua _G.open_netrw_in_file_dir()<CR>', { noremap = true, silent = true })

