return {
    {
        "gaborvecsei/memento.nvim",
        lazy = false,

        init = function()
            vim.g.memento_history = 50
            vim.g.memento_shorten_path = false
        end,

        keys = {
            {
                "<C-p>",
                function()
                    local ns = vim.api.nvim_create_namespace("memento_pretty_paths")

                    local function shorten_all_but_last(path)
                        if type(path) ~= "string" then return path end
                        path = path:gsub("//+", "/")
                        -- directory?
                        if path:sub(-1) == "/" then
                            local parent, last = path:match("^(.-)([^/]+)/$")
                            if parent and last then
                                local shortened = vim.fn.pathshorten(parent)
                                if shortened == "/" then return "/" .. last .. "/" end
                                return shortened .. last .. "/"
                            end
                            return path
                        end
                        -- file
                        local parent, file = path:match("^(.-)([^/]+)$")
                        if parent and file then
                            local shortened = vim.fn.pathshorten(parent)
                            if shortened == "/" then return "/" .. file end
                            return shortened .. file
                        end
                        return path
                    end

                    local function parse_line(line)
                        -- "date/time, /path/, lineno"
                        return line:match("^%s*([^,]+),%s*(.-),%s*(%d+)%s*$")
                    end

                    local function is_memento_lines(lines)
                        local limit = math.min(#lines, 40)
                        for i = 1, limit do
                            local a, p, b = parse_line(lines[i] or "")
                            if a and p and b then return true end
                        end
                        return false
                    end

                    local function build_pretty_lines(lines)
                        local out = {}
                        for i, line in ipairs(lines) do
                            local a, p, b = parse_line(line)
                            if a and p and b then
                                out[i] = string.format("%s, %s, %s", a, shorten_all_but_last(p), b)
                            else
                                out[i] = line
                            end
                        end
                        return out
                    end

                    local function overlay_pretty_lines(win, buf, pretty, orig)
                        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
                        local winw = vim.api.nvim_win_get_width(win)
                        local function dispw(s) return vim.fn.strdisplaywidth(s or "") end
                        for i, s in ipairs(pretty) do
                            local target = math.max(dispw(orig[i] or ""), dispw(s), winw - 1)
                            local pad = target - dispw(s)
                            if pad > 0 then s = s .. string.rep(" ", pad) end
                            vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
                                virt_text = { { s } },
                                virt_text_pos = "overlay",
                                hl_mode = "combine",
                                priority = 10000,
                            })
                        end
                    end

                    local function replace_buffer_with_pretty(buf, pretty)
                        -- Temporarily allow edits on the picker buffer.
                        local ok_mod, was_mod = pcall(vim.api.nvim_buf_get_option, buf, "modifiable")
                        if not ok_mod then was_mod = false end
                        local ok_ro, was_ro = pcall(vim.api.nvim_buf_get_option, buf, "readonly")
                        if not ok_ro then was_ro = false end

                        pcall(vim.api.nvim_buf_set_option, buf, "modifiable", true)
                        pcall(vim.api.nvim_buf_set_option, buf, "readonly", false)

                        -- Replace lines with the pretty text (no padding in the real buffer).
                        local ok_set = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, pretty)

                        -- Restore flags and clear overlays.
                        pcall(vim.api.nvim_buf_set_option, buf, "modifiable", was_mod)
                        pcall(vim.api.nvim_buf_set_option, buf, "readonly", was_ro)
                        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

                        return ok_set
                    end

                    local function find_memento_win_buf()
                        -- Try current window first.
                        local win = vim.api.nvim_get_current_win()
                        local buf = vim.api.nvim_win_get_buf(win)
                        local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
                        if ok and type(lines) == "table" and #lines > 0 and is_memento_lines(lines) then
                            return win, buf, lines
                        end
                        -- Otherwise scan all visible windows.
                        for _, w in ipairs(vim.api.nvim_list_wins()) do
                            local b = vim.api.nvim_win_get_buf(w)
                            local okL, L = pcall(vim.api.nvim_buf_get_lines, b, 0, -1, false)
                            if okL and type(L) == "table" and #L > 0 and is_memento_lines(L) then
                                return w, b, L
                            end
                        end
                        return nil, nil, nil
                    end

                    require("memento").toggle()

                    local tries = 0
                    local function step()
                        tries = tries + 1
                        local win, buf, lines = find_memento_win_buf()
                        if not win or not buf or not lines then
                            if tries < 10 then vim.defer_fn(step, 12) end
                            return
                        end
                        local pretty = build_pretty_lines(lines)
                        -- overlay immediately (no flicker)
                        overlay_pretty_lines(win, buf, pretty, lines)
                        -- replace underlying text shortly after (buffer is non-mod by default)
                        vim.defer_fn(function()
                            replace_buffer_with_pretty(buf, pretty)
                        end, 5)
                    end
                    vim.defer_fn(step, 8)
                end,
                desc = "Memento: Toggle picker (shorten parents; keep last full)",
                mode = "n",
                silent = true,
            },

            {
                "M",
                function() require("memento").clear_history() end,
                desc = "Memento: Clear history",
                mode = "n",
                silent = true,
            },
        },
    },
}

-- return {
--     {
--         "gaborvecsei/memento.nvim",
--         lazy = false,
--         keys = {
--             { "<C-p>", function() require("memento").toggle() end, desc = "Memento: Toggle picker", mode = "n", silent = true },
--             { "M",     function() require("memento").clear_history() end, desc = "Memento: Clear history", mode = "n", silent = true },
--         },
--         init = function()
--             vim.g.memento_history = 50
--             vim.g.memento_shorten_path = false
--         end,
--     },
-- }

