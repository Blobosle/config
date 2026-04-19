return {
    'nvim-lualine/lualine.nvim',

    init = function()
        local git_branch = function()
            local file_dir = vim.fn.expand('%:p:h')
            if file_dir == '' then
                file_dir = vim.loop.cwd()
            end

            local git_path = vim.fn.finddir('.git', file_dir .. ';')
            if git_path == '' then
                git_path = vim.fn.findfile('.git', file_dir .. ';')
            end

            if git_path == '' then
                return ''
            end

            if vim.fn.filereadable(git_path) == 1 then
                local git_file = vim.fn.readfile(git_path, '', 1)[1] or ''
                local git_dir = git_file:match('gitdir: (.+)')
                if not git_dir then
                    return ''
                end
                if not vim.startswith(git_dir, '/') then
                    git_dir = vim.fn.fnamemodify(git_path, ':h') .. '/' .. git_dir
                end
                git_path = git_dir
            end

            local head_path = git_path .. '/HEAD'
            if vim.fn.filereadable(head_path) == 0 then
                return ''
            end

            local head = vim.fn.readfile(head_path, '', 1)[1] or ''
            return head:match('ref: refs/heads/(.+)') or ''
        end

        _G.UserWinbar = function()
            if vim.fn.getcmdwintype() ~= '' then
                return ''
            end

            local parts = {}
            local filename = vim.fn.expand('%:t')
            if filename ~= '' then
                table.insert(parts, filename)
            end

            table.insert(parts, string.format('[%d]:[%d]', vim.fn.line('.'), vim.fn.col('.')))

            local branch = git_branch()
            if branch ~= '' then
                table.insert(parts, branch)
            end

            return table.concat(parts, ' '):gsub('%%', '%%%%')
        end

        _G.UserStatusSeparator = function()
            return string.rep('─', math.max(vim.api.nvim_win_get_width(0), 1))
        end

        local set_transparent_bar = function()
            local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
            local foreground = normal_hl.fg and string.format('#%06x', normal_hl.fg) or '#d8dee9'

            vim.cmd('highlight WinBar guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
            vim.cmd('highlight WinBarNC guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
            vim.cmd('highlight StatusLine guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
            vim.cmd('highlight StatusLineNC guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
            vim.cmd('highlight WinSeparator guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
        end

        vim.opt.laststatus = 0
        vim.opt.cmdheight = 1
        vim.opt.statusline = '%#StatusLine#%{%v:lua.UserStatusSeparator()%}'

        local user_winbar = '%{%v:lua.UserWinbar()%}'

        local apply_winbar = function(win)
            if not vim.api.nvim_win_is_valid(win) then
                return
            end

            if vim.fn.getcmdwintype() ~= '' then
                vim.api.nvim_win_set_option(win, 'winbar', '')
            else
                vim.api.nvim_win_set_option(win, 'winbar', user_winbar)
            end
        end

        local apply_winbars = function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                apply_winbar(win)
            end
        end

        vim.opt.winbar = ''
        apply_winbars()

        set_transparent_bar()
        vim.api.nvim_create_autocmd('ColorScheme', {
            callback = set_transparent_bar,
        })
        local winbar_grp = vim.api.nvim_create_augroup('UserWinbar', { clear = true })
        vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'WinNew', 'WinClosed', 'VimResized', 'CmdwinLeave' }, {
            group = winbar_grp,
            callback = function()
                vim.schedule(apply_winbars)
            end,
        })
        vim.api.nvim_create_autocmd('CmdwinEnter', {
            group = winbar_grp,
            callback = function()
                vim.api.nvim_win_set_option(0, 'winbar', '')
            end,
        })
    end,
}
