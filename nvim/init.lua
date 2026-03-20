require("config.lazy")
require("user")

_G.color = "onedark"

-- vim.cmd("set number")
vim.cmd("set linebreak")
vim.cmd("set ruler")
vim.cmd("set expandtab ")
vim.cmd("set scrolloff=5")

vim.cmd("set tabstop=4")
vim.cmd("set shiftwidth=4")
vim.cmd("set softtabstop=4")

vim.cmd("set list")
vim.cmd("set ignorecase smartcase")
vim.cmd("set listchars=tab:>.,trail:•")

vim.cmd("colorscheme " .. _G.color)

vim.opt.hlsearch = true
vim.opt.incsearch = true
-- vim.opt.relativenumber = true
vim.opt.guicursor = ""
vim.opt.swapfile = false
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.splitright = true

