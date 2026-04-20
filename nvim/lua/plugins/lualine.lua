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

        local top_message = { text = '', hl = 'UserTopMessage' }
        local top_message_timer
        local cmdline_active = false
        local bottom_cmdline_active = false
        local bottom_cmdline_prefix = ''
        local bottom_cmdline = {}
        local bottom_cmdline_ns = vim.api.nvim_create_namespace('UserBottomCmdline')
        local message_output = {}
        local refresh_winbars = function() end

        local clean_message = function(text)
            return (text or ''):gsub('\n.*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        end

        local content_text = function(content)
            local chunks = {}
            for _, chunk in ipairs(content or {}) do
                table.insert(chunks, chunk[2] or '')
            end
            return table.concat(chunks, '')
        end

        local set_top_message = function(text, hl, timeout)
            text = clean_message(text)
            if text == '' then
                top_message.text = ''
            else
                top_message.text = text
                top_message.hl = hl or 'UserTopMessage'
            end

            if top_message_timer and not top_message_timer:is_closing() then
                top_message_timer:stop()
                top_message_timer:close()
            end
            top_message_timer = nil

            if timeout and text ~= '' then
                top_message_timer = vim.defer_fn(function()
                    top_message.text = ''
                    top_message_timer = nil
                    refresh_winbars()
                end, timeout)
            end

            refresh_winbars()
        end

        local has_timed_top_message = function()
            return top_message_timer and not top_message_timer:is_closing()
        end

        local fit_text = function(text, width)
            if vim.fn.strdisplaywidth(text) <= width then
                return text
            end

            local available = math.max(width - 1, 0)
            local chars = vim.fn.strchars(text)
            for start = 1, chars do
                local candidate = vim.fn.strcharpart(text, start)
                if vim.fn.strdisplaywidth(candidate) <= available then
                    return '<' .. candidate
                end
            end

            return '<'
        end

        local close_bottom_cmdline = function()
            if bottom_cmdline.win and vim.api.nvim_win_is_valid(bottom_cmdline.win) then
                vim.api.nvim_win_close(bottom_cmdline.win, true)
            end

            bottom_cmdline.win = nil
        end

        local show_bottom_cmdline = function(text)
            local width = math.max(vim.o.columns, 1)
            local line = fit_text(text or '', width)
            local padding = string.rep(' ', math.max(width - vim.fn.strdisplaywidth(line), 0))

            if not bottom_cmdline.buf or not vim.api.nvim_buf_is_valid(bottom_cmdline.buf) then
                bottom_cmdline.buf = vim.api.nvim_create_buf(false, true)
            end

            vim.api.nvim_buf_set_lines(bottom_cmdline.buf, 0, -1, false, { line .. padding })
            vim.api.nvim_buf_clear_namespace(bottom_cmdline.buf, bottom_cmdline_ns, 0, -1)
            vim.api.nvim_buf_set_extmark(bottom_cmdline.buf, bottom_cmdline_ns, 0, 0, {
                end_col = #line,
                hl_group = 'UserTopCommand',
            })

            local config = {
                relative = 'editor',
                row = math.max(vim.o.lines - 1, 0),
                col = 0,
                width = width,
                height = 1,
                focusable = false,
                style = 'minimal',
                zindex = 200,
            }

            if bottom_cmdline.win and vim.api.nvim_win_is_valid(bottom_cmdline.win) then
                vim.api.nvim_win_set_config(bottom_cmdline.win, config)
            else
                bottom_cmdline.win = vim.api.nvim_open_win(bottom_cmdline.buf, false, config)
                vim.api.nvim_win_set_option(bottom_cmdline.win, 'winhighlight', 'Normal:Normal,NormalFloat:Normal')
                vim.api.nvim_win_set_option(bottom_cmdline.win, 'wrap', false)
            end
        end

        local close_message_output = function()
            if message_output.win and vim.api.nvim_win_is_valid(message_output.win) then
                vim.api.nvim_win_close(message_output.win, true)
            end

            message_output.win = nil
        end

        local show_message_output = function(text)
            local lines = vim.split(text:gsub('\r\n', '\n'), '\n', { plain = true })
            while #lines > 1 and lines[1] == '' do
                table.remove(lines, 1)
            end
            while #lines > 1 and lines[#lines] == '' do
                table.remove(lines)
            end

            local width = math.max(vim.o.columns, 1)
            local height = math.min(math.max(#lines, 1), math.max(math.floor(vim.o.lines * 0.5), 1))

            if not message_output.buf or not vim.api.nvim_buf_is_valid(message_output.buf) then
                message_output.buf = vim.api.nvim_create_buf(false, true)
                vim.bo[message_output.buf].buftype = 'nofile'
                vim.bo[message_output.buf].bufhidden = 'wipe'
                vim.bo[message_output.buf].swapfile = false
                vim.bo[message_output.buf].filetype = 'output'
            end

            vim.bo[message_output.buf].modifiable = true
            vim.api.nvim_buf_set_lines(message_output.buf, 0, -1, false, lines)
            vim.bo[message_output.buf].modifiable = false

            local config = {
                relative = 'editor',
                row = math.max(vim.o.lines - height - vim.o.cmdheight, 0),
                col = 0,
                width = width,
                height = height,
                focusable = true,
                style = 'minimal',
                border = 'single',
                zindex = 190,
            }

            if message_output.win and vim.api.nvim_win_is_valid(message_output.win) then
                vim.api.nvim_win_set_config(message_output.win, config)
                vim.api.nvim_set_current_win(message_output.win)
            else
                message_output.win = vim.api.nvim_open_win(message_output.buf, true, config)
                vim.api.nvim_win_set_option(
                    message_output.win,
                    'winhighlight',
                    'Normal:UserMessageOutput,NormalFloat:UserMessageOutput,FloatBorder:UserMessageOutputBorder'
                )
                vim.api.nvim_win_set_option(message_output.win, 'wrap', false)
            end

            vim.keymap.set('n', 'q', close_message_output, { buffer = message_output.buf, silent = true, nowait = true })
            vim.keymap.set('n', '<Esc>', close_message_output, { buffer = message_output.buf, silent = true, nowait = true })
        end

        local render_statusline_parts = function(parts)
            local chunks = {}

            for _, part in ipairs(parts) do
                local text = part.text:gsub('%%', '%%%%')
                if part.hl then
                    table.insert(chunks, '%#' .. part.hl .. '#' .. text .. '%#WinBar#')
                else
                    table.insert(chunks, text)
                end
            end

            return table.concat(chunks, ' ')
        end

        _G.UserTopMessageParts = function()
            if top_message.text == '' then
                return {}
            end

            return { { text = top_message.text, hl = top_message.hl } }
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
            local winbar = render_statusline_parts(_G.UserWinbarParts())
            local message = render_statusline_parts(_G.UserTopMessageParts())

            if message ~= '' then
                return winbar .. '%=' .. message
            end

            return winbar
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
            vim.api.nvim_set_hl(0, 'UserTopMessage', { fg = foreground, bg = 'NONE' })
            vim.api.nvim_set_hl(0, 'UserTopError', { fg = '#e06c75', bg = 'NONE' })
            vim.api.nvim_set_hl(0, 'UserTopWarning', { fg = '#e5c07b', bg = 'NONE' })
            vim.api.nvim_set_hl(0, 'UserTopCommand', { fg = '#61afef', bg = 'NONE' })
            vim.api.nvim_set_hl(0, 'UserMessageOutput', { fg = foreground, bg = 'NONE' })
            vim.api.nvim_set_hl(0, 'UserMessageOutputBorder', { fg = '#ffffff', bg = 'NONE' })
        end

        vim.opt.laststatus = 0
        vim.opt.cmdheight = 1
        vim.opt.showmode = false
        vim.opt.statusline = '%#StatusLine#%{%v:lua.UserStatusSeparator()%}'

        local left_winbar = '%{%v:lua.UserWinbar()%}'
        local overlay_by_win = {}
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
            if overlay and overlay.message_win and vim.api.nvim_win_is_valid(overlay.message_win) then
                vim.api.nvim_win_close(overlay.message_win, true)
            end
            overlay_by_win[win] = nil
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

            local message_parts = _G.UserTopMessageParts()
            if #message_parts == 0 then
                if overlay.message_win and vim.api.nvim_win_is_valid(overlay.message_win) then
                    vim.api.nvim_win_close(overlay.message_win, true)
                end
                overlay.message_win = nil
                return
            end

            local message_label = parts_label(message_parts)
            local message_max_width = math.max(width, 1)
            local message_width = math.min(vim.fn.strdisplaywidth(message_label), message_max_width)
            local message_col = math.max(width - message_width, 0)

            if not overlay.message_buf or not vim.api.nvim_buf_is_valid(overlay.message_buf) then
                overlay.message_buf = vim.api.nvim_create_buf(false, true)
            end

            vim.api.nvim_buf_set_lines(overlay.message_buf, 0, -1, false, { message_label })
            apply_overlay_highlights(overlay.message_buf, message_parts)

            local message_config = {
                relative = 'win',
                win = win,
                row = 1,
                col = message_col,
                width = message_width,
                height = 1,
                focusable = false,
                style = 'minimal',
                zindex = 60,
            }

            if overlay.message_win and vim.api.nvim_win_is_valid(overlay.message_win) then
                vim.api.nvim_win_set_config(overlay.message_win, message_config)
            else
                overlay.message_win = vim.api.nvim_open_win(overlay.message_buf, false, message_config)
                vim.api.nvim_win_set_option(overlay.message_win, 'winhighlight', 'Normal:WinBar,NormalFloat:WinBar')
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

        refresh_winbars = apply_winbars

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
            'ModeChanged',
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

        local message_hl = function(kind)
            if kind == 'emsg' or kind == 'echoerr' or kind == 'lua_error' or kind == 'rpc_error' then
                return 'UserTopError'
            end
            if kind == 'wmsg' then
                return 'UserTopWarning'
            end
            return 'UserTopMessage'
        end

        if vim.ui_attach then
            local message_ns = vim.api.nvim_create_namespace('UserTopMessages')
            pcall(vim.ui_attach, message_ns, { ext_messages = true }, function(event, ...)
                if event == 'msg_show' then
                    local kind, content = ...
                    local text = content_text(content)
                    if text ~= '' and kind ~= 'return_prompt' then
                        vim.schedule(function()
                            if kind == 'list_cmd' or text:find('\n', 1, true) then
                                show_message_output(text)
                            else
                                set_top_message(text, message_hl(kind), 3000)
                            end
                        end)
                    end
                elseif event == 'msg_clear' then
                    vim.schedule(function()
                        if not cmdline_active and not has_timed_top_message() then
                            set_top_message('')
                        end
                    end)
                elseif event == 'cmdline_show' then
                    local content, _, firstc, prompt = ...
                    vim.schedule(function()
                        cmdline_active = true
                        if firstc == ':' then
                            bottom_cmdline_active = true
                            bottom_cmdline_prefix = (firstc or '') .. (prompt or '')
                        end
                        local text = (firstc or '') .. (prompt or '') .. content_text(content)
                        if bottom_cmdline_active then
                            text = bottom_cmdline_prefix .. content_text(content)
                            show_bottom_cmdline(text)
                        else
                            set_top_message(text, 'UserTopCommand')
                        end
                    end)
                elseif event == 'cmdline_hide' then
                    vim.schedule(function()
                        cmdline_active = false
                        bottom_cmdline_active = false
                        bottom_cmdline_prefix = ''
                        close_bottom_cmdline()
                        if not has_timed_top_message() then
                            set_top_message('')
                        end
                    end)
                elseif event == 'cmdline_block_show' then
                    local lines = ...
                    local text = {}
                    for _, line in ipairs(lines or {}) do
                        table.insert(text, content_text(line))
                    end
                    vim.schedule(function()
                        set_top_message(table.concat(text, ' '), 'UserTopCommand')
                    end)
                elseif event == 'cmdline_block_append' then
                    local line = ...
                    vim.schedule(function()
                        set_top_message(content_text(line), 'UserTopCommand')
                    end)
                elseif event == 'cmdline_block_hide' then
                    vim.schedule(function()
                        if cmdline_active and not has_timed_top_message() then
                            set_top_message('')
                        end
                    end)
                end
            end)
        end
    end,
}
