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

        local set_transparent_bar = function()
            local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
            local foreground = normal_hl.fg and string.format('#%06x', normal_hl.fg) or '#d8dee9'

            vim.cmd('highlight WinBar guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
            vim.cmd('highlight WinBarNC guifg=' .. foreground .. ' guibg=NONE gui=NONE ctermbg=NONE cterm=NONE')
        end

        vim.opt.laststatus = 0
        vim.opt.cmdheight = 1
        vim.opt.winbar = '%{%v:lua.UserWinbar()%}'

        set_transparent_bar()
        vim.api.nvim_create_autocmd('ColorScheme', {
            callback = set_transparent_bar,
        })
    end,
}
