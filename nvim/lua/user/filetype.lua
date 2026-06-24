vim.filetype.add({
    filename = {
        Makefile = "make",
        makefile = "make",
    },
    pattern = {
        [".*/[^./]+"] = { "text", { priority = math.huge } },
    },
})
