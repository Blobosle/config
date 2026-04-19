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
                table.insert(parts, ' ' .. branch)
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
        end

        vim.opt.laststatus = 0
        vim.opt.cmdheight = 1
        vim.opt.statusline = '%#StatusLine#%{%v:lua.UserStatusSeparator()%}'

        local left_winbar = '%{%v:lua.UserWinbar()%}'
        local overlay_by_win = {}

        local should_skip_winbar = function(win)
            if not vim.api.nvim_win_is_valid(win) then
                return true
            end

            local config = vim.api.nvim_win_get_config(win)
            if config.relative ~= '' then
                return true
            end

            local buf = vim.api.nvim_win_get_buf(win)
            local buftype = vim.bo[buf].buftype
            if buftype ~= '' then
                return true
            end

            local filetype = vim.bo[buf].filetype
            return filetype == 'netrw'
                or filetype == 'TelescopePrompt'
                or filetype == 'TelescopeResults'
                or filetype == 'TelescopePreview'
                or filetype == 'prompt'
            end

        local has_vertical_split = function()
            local rows = {}
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == '' then
                    local pos = vim.api.nvim_win_get_position(win)
                    local row = pos[1]
                    local col = pos[2]
                    if rows[row] ~= nil and rows[row] ~= col then
                        return true
                    end
                    rows[row] = col
                end
            end

            return false
        end

        local close_overlay = function(win)
            local overlay = overlay_by_win[win]
            if overlay and overlay.win and vim.api.nvim_win_is_valid(overlay.win) then
                vim.api.nvim_win_close(overlay.win, true)
            end
            overlay_by_win[win] = nil
        end

        local update_overlay = function(win)
            if should_skip_winbar(win) then
                close_overlay(win)
                return
            end

            local label = vim.api.nvim_win_call(win, _G.UserWinbar)
            if label == '' then
                close_overlay(win)
                return
            end

            local width = vim.api.nvim_win_get_width(win)
            local label_width = math.min(vim.fn.strdisplaywidth(label), width)
            local col = math.max(width - label_width, 0)
            local overlay = overlay_by_win[win]

            if not overlay or not overlay.buf or not vim.api.nvim_buf_is_valid(overlay.buf) then
                overlay = { buf = vim.api.nvim_create_buf(false, true) }
                overlay_by_win[win] = overlay
            end

            vim.api.nvim_buf_set_lines(overlay.buf, 0, -1, false, { label })

            local config = {
                relative = 'win',
                win = win,
                row = 0,
                col = col,
                width = label_width,
                height = 1,
                focusable = false,
                style = 'minimal',
                zindex = 60,
            }

            if overlay.win and vim.api.nvim_win_is_valid(overlay.win) then
                vim.api.nvim_win_set_config(overlay.win, config)
            else
                overlay.win = vim.api.nvim_open_win(overlay.buf, false, config)
                vim.api.nvim_win_set_option(overlay.win, 'winhighlight', 'Normal:WinBar,NormalFloat:WinBar')
            end
        end

        local apply_winbar = function(win, use_native_winbar)
            if not vim.api.nvim_win_is_valid(win) then
                return
            end

            if vim.fn.getcmdwintype() ~= '' or should_skip_winbar(win) then
                vim.api.nvim_win_set_option(win, 'winbar', '')
                close_overlay(win)
            elseif use_native_winbar then
                close_overlay(win)
                vim.api.nvim_win_set_option(win, 'winbar', left_winbar)
            else
                vim.api.nvim_win_set_option(win, 'winbar', '')
                update_overlay(win)
            end
        end

        local apply_winbars = function()
            local use_native_winbar = has_vertical_split()
            local active_wins = {}

            for _, win in ipairs(vim.api.nvim_list_wins()) do
                active_wins[win] = true
                apply_winbar(win, use_native_winbar)
            end

            for win, _ in pairs(overlay_by_win) do
                if not active_wins[win] then
                    close_overlay(win)
                end
            end
        end

        vim.opt.winbar = ''
        apply_winbars()

        set_transparent_bar()
        vim.api.nvim_create_autocmd('ColorScheme', {
            callback = set_transparent_bar,
        })
        local winbar_grp = vim.api.nvim_create_augroup('UserWinbar', { clear = true })
        vim.api.nvim_create_autocmd({
            'BufEnter',
            'BufWinEnter',
            'CursorMoved',
            'CursorMovedI',
            'FileType',
            'WinEnter',
            'WinNew',
            'WinClosed',
            'VimResized',
            'CmdwinLeave',
        }, {
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
