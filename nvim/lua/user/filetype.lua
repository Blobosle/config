vim.filetype.add({
    pattern = {
        [".*/[^./]+"] = { "text", { priority = math.huge } },
    },
})
