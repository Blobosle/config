-- Disables line numbers in terminal mode
function DisableLineNumbers()
  vim.wo.number = false
  vim.wo.relativenumber = false
end

-- Enables line numbers in normal mode
function EnableLineNumbers()
  vim.wo.number = true
  vim.wo.relativenumber = true
end

-- Toggles line numbers in terminal mode
vim.api.nvim_exec([[
  augroup TermNumberToggle
    autocmd!
    autocmd TermOpen * lua DisableLineNumbers()
    autocmd TermClose * lua EnableLineNumbers()
  augroup END
]], false)

-- -- Custom highlight group for terminal windows
vim.cmd('hi TermNormal guifg=white ctermbg=0 ctermfg=white')
-- vim.cmd('hi TermNormal guibg=#1e1e1e guifg=white ctermbg=0 ctermfg=white')

-- Autocommand to set winhighlight in terminal windows
vim.api.nvim_exec([[
  augroup TermColorschemeToggle
    autocmd!
    autocmd TermOpen * setlocal winhighlight=Normal:TermNormal
  augroup END
]], false)

-- -- Command to get rid of the neovim status line
-- vim.cmd('hi TermStatusLine guibg=#1e1e1e guifg=white ctermbg=0 ctermfg=white')
--
-- -- Implements the modified status line
-- function _G.SetTermStatusLineHighlight()
--     vim.wo.statusline = '%#TermStatusLine#' .. vim.o.statusline
-- end
--
-- -- Executes status line code to remove it
-- vim.api.nvim_exec([[
--     augroup TermStatusLineHighlight
--         autocmd!
--         autocmd TermOpen * lua _G.SetTermStatusLineHighlight()
--     augroup END
-- ]], false)
--
-- vim.api.nvim_exec([[
--   augroup TermStatusLineRestore
--     autocmd!
--     " On terminal close, clear the custom status line highlight and winhighlight
--     autocmd TermClose * setlocal statusline=
--     autocmd TermClose * setlocal winhighlight=
--   augroup END
-- ]], false)

-- Skips unnecesary terminal instance closing sequence
vim.api.nvim_create_autocmd("TermClose", {
    pattern = "*",
    callback = function(args)
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
                local success, err = pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
                if not success then
                    vim.notify("Error deleting buffer: " .. err, vim.log.levels.ERROR)
                end
            end
        end)
    end,
})
