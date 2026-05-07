local grp = vim.api.nvim_create_augroup("BinaryPreview", { clear = true })

local function shellescape(path)
    return vim.fn.shellescape(vim.fn.fnamemodify(path, ":p"))
end

local function systemlist(cmd)
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 or not out or vim.tbl_isempty(out) then
        return nil
    end
    return out
end

local function file_mime(path)
    local out = systemlist("file -b --mime " .. shellescape(path) .. " 2>/dev/null")
    return out and out[1] or nil
end

local function file_desc(path)
    local out = systemlist("file -b " .. shellescape(path) .. " 2>/dev/null")
    return out and out[1] or nil
end

local function is_binary(path)
    local mime = file_mime(path)
    if not mime then
        return false
    end

    if mime:match("^application/pdf") then
        return false
    end

    if mime:match("charset=binary") then
        return true
    end

    return mime:match("^application/") ~= nil
end

local function is_macho(path)
    local desc = file_desc(path)
    return desc and desc:match("Mach%-O") ~= nil or false
end

local function is_executable(path)
    return vim.fn.executable(path) == 1
end

local function has(cmd)
    return vim.fn.executable(cmd) == 1
end

local function is_elf(path)
    local desc = file_desc(path)
    return desc and desc:match("ELF") ~= nil or false
end

local function disasm_command(path)
    local escaped = shellescape(path)

    if is_macho(path) and has("otool") then
        return "otool -tvV " .. escaped .. " 2>/dev/null", "asm"
    end

    if is_elf(path) and has("objdump") then
        return "objdump -d -M intel " .. escaped .. " 2>/dev/null", "asm"
    end

    if has("objdump") then
        return "objdump -d " .. escaped .. " 2>/dev/null", "asm"
    end

    return nil, nil
end

local function headers_command(path)
    local escaped = shellescape(path)

    if is_macho(path) and has("otool") then
        return "otool -l " .. escaped .. " 2>/dev/null", "text"
    end

    if is_elf(path) and has("readelf") then
        return "readelf -a " .. escaped .. " 2>/dev/null", "text"
    end

    if has("objdump") then
        return "objdump -x " .. escaped .. " 2>/dev/null", "text"
    end

    return nil, nil
end

local function preview_command(path)
    local cmd, ft

    if is_executable(path) then
        cmd, ft = disasm_command(path)
        if cmd then
            return cmd, ft
        end
    end

    if is_executable(path) then
        return "strings -a " .. shellescape(path) .. " 2>/dev/null", "text"
    end

    return "xxd " .. shellescape(path) .. " 2>/dev/null", "xxd"
end

local function render_preview(buf, path)
    local cmd, ft = preview_command(path)
    local lines = systemlist(cmd)

    if not lines then
        lines = {
            "Failed to render binary preview.",
            "",
            "Path: " .. path,
            "Command: " .. cmd,
        }
        ft = "text"
    elseif vim.tbl_isempty(lines) then
        lines = { "[no preview output]" }
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = ft
    vim.b[buf].binary_preview = true
    vim.b[buf].binary_preview_source = path
    vim.b[buf].binary_preview_command = cmd
end

vim.api.nvim_create_autocmd("BufReadPost", {
    group = grp,
    pattern = "*",
    callback = function(args)
        local buf = args.buf
        local path = vim.api.nvim_buf_get_name(buf)

        if path == "" or vim.fn.isdirectory(path) == 1 then
            return
        end

        if vim.bo[buf].buftype ~= "" then
            return
        end

        if not is_binary(path) then
            return
        end

        render_preview(buf, path)
    end,
})
