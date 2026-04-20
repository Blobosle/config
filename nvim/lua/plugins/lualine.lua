return {
    'nvim-lualine/lualine.nvim',

    init = function()
        local ctrl_v = vim.api.nvim_replace_termcodes('<C-V>', true, true, true)
        local ctrl_s = vim.api.nvim_replace_termcodes('<C-S>', true, true, true)

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

        local mode_labels = {
            n = 'N',
            no = 'O',
            nov = 'O',
            noV = 'O',
            niI = 'N',
            niR = 'N',
            niV = 'N',
            i = 'I',
            ic = 'I',
            ix = 'I',
            v = 'V',
            V = 'VL',
            [ctrl_v] = 'VB',
            s = 'S',
            S = 'SL',
            [ctrl_s] = 'SB',
            R = 'R',
            Rv = 'RV',
            c = 'C',
            cv = 'EX',
            ce = 'EX',
            r = 'P',
            rm = 'M',
            ['r?'] = '?',
            ['!'] = 'SH',
            t = 'T',
        }

        local mode_hls = {
            n = 'UserModeNormal',
            no = 'UserModeNormal',
            nov = 'UserModeNormal',
            noV = 'UserModeNormal',
            niI = 'UserModeNormal',
            niR = 'UserModeNormal',
            niV = 'UserModeNormal',
            i = 'UserModeInsert',
            ic = 'UserModeInsert',
            ix = 'UserModeInsert',
            v = 'UserModeVisual',
            V = 'UserModeVisual',
            [ctrl_v] = 'UserModeVisual',
            s = 'UserModeSelect',
            S = 'UserModeSelect',
            [ctrl_s] = 'UserModeSelect',
            R = 'UserModeReplace',
            Rv = 'UserModeReplace',
            c = 'UserModeCommand',
            cv = 'UserModeCommand',
            ce = 'UserModeCommand',
            r = 'UserModeCommand',
            rm = 'UserModeCommand',
            ['r?'] = 'UserModeCommand',
            ['!'] = 'UserModeTerminal',
            t = 'UserModeTerminal',
        }

        local mode_indicator = function()
            local mode = vim.fn.mode(1)
            return mode_labels[mode] or mode_labels[mode:sub(1, 1)] or mode:sub(1, 2):upper(),
                mode_hls[mode] or mode_hls[mode:sub(1, 1)] or 'UserModeNormal'
        end

        local apply_winbars
        local top_message = {
            text = nil,
            timer = nil,
        }

        local refresh_winbars = function()
            if apply_winbars then
                vim.schedule(apply_winbars)
            end
        end

        local clear_top_message = function(message)
            if message ~= nil and top_message.text ~= message then
                return
            end

            top_message.text = nil
            refresh_winbars()
        end

        local show_top_message = function(message)
            message = vim.trim((message or ''):gsub('[\r\n]+', ' '):gsub('%s+', ' '))
            if message == '' then
                return
            end

            top_message.text = message
            if not top_message.timer then
                top_message.timer = vim.uv.new_timer()
            else
                top_message.timer:stop()
            end

            top_message.timer:start(3500, 0, function()
                vim.schedule(function()
                    clear_top_message(message)
                end)
            end)

            refresh_winbars()
        end

        local last_messages = nil
        local latest_message_line = function(messages)
            local latest = nil
            for line in vim.gsplit(messages or '', '\n', { plain = true, trimempty = true }) do
                local trimmed = vim.trim(line)
                if trimmed ~= '' then
                    latest = trimmed
                end
            end

            return latest
        end

        local capture_status_message = function()
            local ok, messages = pcall(vim.fn.execute, 'messages', 'silent')
            if not ok or messages == last_messages then
                return
            end

            last_messages = messages
            local status_message = vim.trim(vim.v.statusmsg or '')
            if status_message == '' then
                return
            end

            local latest = latest_message_line(messages)
            if latest == status_message then
                show_top_message(status_message)
            end
        end

        local escape_statusline_text = function(text)
            return text:gsub('%%', '%%%%')
        end

        local render_statusline_parts = function(parts)
            local chunks = {}

            for _, part in ipairs(parts) do
                local text = escape_statusline_text(part.text)
                if part.hl then
                    table.insert(chunks, '%#' .. part.hl .. '#' .. text .. '%#WinBar#')
                else
                    table.insert(chunks, text)
                end
            end

            return table.concat(chunks, ' ')
        end

        _G.UserWinbarParts = function()
            if vim.fn.getcmdwintype() ~= '' then
                return {}
            end

            local parts = {}
            local filename = vim.fn.expand('%:t')
            if filename ~= '' then
                table.insert(parts, { text = filename })
            end

            local mode_text, mode_hl = mode_indicator()
            table.insert(parts, { text = mode_text, hl = mode_hl })

            table.insert(parts, { text = string.format('[%d]:[%d]', vim.fn.line('.'), vim.fn.col('.')) })

            local branch = git_branch()
            if branch ~= '' then
                table.insert(parts, { text = ' ' .. branch })
            end

            return parts
        end

        _G.UserWinbar = function()
            return render_statusline_parts(_G.UserWinbarParts())
        end

        _G.UserWinbarWithMessage = function()
            local winbar = _G.UserWinbar()
            if not top_message.text then
                return winbar
            end

            return winbar .. '%=%#UserStatusMessage#' .. escape_statusline_text(top_message.text) .. '%#WinBar#'
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
            vim.api.nvim_set_hl(0, 'UserModeNormal', { fg = '#61afef', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserModeInsert', { fg = '#98c379', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserModeVisual', { fg = '#c678dd', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserModeSelect', { fg = '#c678dd', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserModeReplace', { fg = '#e06c75', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserModeCommand', { fg = '#e5c07b', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserModeTerminal', { fg = '#56b6c2', bg = 'NONE', bold = true })
            vim.api.nvim_set_hl(0, 'UserStatusMessage', { fg = foreground, bg = 'NONE', bold = false })
        end

        vim.opt.laststatus = 0
        vim.opt.cmdheight = 0
        vim.opt.showmode = false
        vim.opt.statusline = '%#StatusLine#%{%v:lua.UserStatusSeparator()%}'

        local left_winbar = '%{%v:lua.UserWinbarWithMessage()%}'
        local overlay_by_win = {}
        local message_overlay_by_win = {}
        local overlay_ns = vim.api.nvim_create_namespace('UserWinbarOverlay')

        local parts_label = function(parts)
            local texts = {}
            for _, part in ipairs(parts) do
                table.insert(texts, part.text)
            end

            return table.concat(texts, ' ')
        end

        local apply_overlay_highlights = function(buf, parts)
            vim.api.nvim_buf_clear_namespace(buf, overlay_ns, 0, -1)

            local part_col = 0
            for index, part in ipairs(parts) do
                if part.hl then
                    vim.api.nvim_buf_set_extmark(buf, overlay_ns, 0, part_col, {
                        end_col = part_col + #part.text,
                        hl_group = part.hl,
                    })
                end

                part_col = part_col + #part.text
                if index < #parts then
                    part_col = part_col + 1
                end
            end
        end

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

        local close_message_overlay = function(win)
            local overlay = message_overlay_by_win[win]
            if overlay and overlay.win and vim.api.nvim_win_is_valid(overlay.win) then
                vim.api.nvim_win_close(overlay.win, true)
            end
            message_overlay_by_win[win] = nil
        end

        local update_overlay = function(win)
            if should_skip_winbar(win) then
                close_overlay(win)
                return
            end

            local parts = vim.api.nvim_win_call(win, _G.UserWinbarParts)
            if #parts == 0 then
                close_overlay(win)
                return
            end

            local label = parts_label(parts)
            local width = vim.api.nvim_win_get_width(win)
            local label_width = math.min(vim.fn.strdisplaywidth(label), width)
            local col = math.max(width - label_width, 0)
            local overlay = overlay_by_win[win]

            if not overlay or not overlay.buf or not vim.api.nvim_buf_is_valid(overlay.buf) then
                overlay = { buf = vim.api.nvim_create_buf(false, true) }
                overlay_by_win[win] = overlay
            end

            vim.api.nvim_buf_set_lines(overlay.buf, 0, -1, false, { label })
            apply_overlay_highlights(overlay.buf, parts)

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

        local update_message_overlay = function(win, use_native_winbar)
            if should_skip_winbar(win) or not top_message.text then
                close_message_overlay(win)
                return
            end

            local width = vim.api.nvim_win_get_width(win)
            local height = vim.api.nvim_win_get_height(win)
            local label_width = math.min(vim.fn.strdisplaywidth(top_message.text), width)
            local row = use_native_winbar and 0 or 1
            if row >= height then
                row = 0
            end

            local overlay = message_overlay_by_win[win]
            if not overlay or not overlay.buf or not vim.api.nvim_buf_is_valid(overlay.buf) then
                overlay = { buf = vim.api.nvim_create_buf(false, true) }
                message_overlay_by_win[win] = overlay
            end

            vim.api.nvim_buf_set_lines(overlay.buf, 0, -1, false, { top_message.text })

            local config = {
                relative = 'win',
                win = win,
                row = row,
                col = math.max(width - label_width, 0),
                width = label_width,
                height = 1,
                focusable = false,
                style = 'minimal',
                zindex = 61,
            }

            if overlay.win and vim.api.nvim_win_is_valid(overlay.win) then
                vim.api.nvim_win_set_config(overlay.win, config)
            else
                overlay.win = vim.api.nvim_open_win(overlay.buf, false, config)
                vim.api.nvim_win_set_option(overlay.win, 'winhighlight', 'Normal:UserStatusMessage,NormalFloat:UserStatusMessage')
            end
        end

        local apply_winbar = function(win, use_native_winbar)
            if not vim.api.nvim_win_is_valid(win) then
                return
            end

            if vim.fn.getcmdwintype() ~= '' or should_skip_winbar(win) then
                vim.api.nvim_win_set_option(win, 'winbar', '')
                close_overlay(win)
                close_message_overlay(win)
            elseif use_native_winbar then
                close_overlay(win)
                close_message_overlay(win)
                vim.api.nvim_win_set_option(win, 'winbar', left_winbar)
            else
                vim.api.nvim_win_set_option(win, 'winbar', '')
                update_overlay(win)
                update_message_overlay(win, use_native_winbar)
            end
        end

        apply_winbars = function()
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

            for win, _ in pairs(message_overlay_by_win) do
                if not active_wins[win] then
                    close_message_overlay(win)
                end
            end
        end

        vim.opt.winbar = ''
        apply_winbars()
        last_messages = vim.fn.execute('messages', 'silent')

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
            'ModeChanged',
            'CmdwinLeave',
        }, {
            group = winbar_grp,
            callback = function()
                vim.schedule(apply_winbars)
            end,
        })
        vim.api.nvim_create_autocmd({
            'BufWritePost',
            'CmdlineLeave',
            'QuickFixCmdPost',
            'ShellCmdPost',
            'TextChanged',
            'TextChangedI',
        }, {
            group = winbar_grp,
            callback = function()
                vim.schedule(capture_status_message)
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
