for _, m in ipairs({
    "filetype",
    "remaps",
    "netrw",
    "tab",
    "term",
    "cursor-jump",
    "comments",
    "indent",
    "spell",
    "func-telescope",
    "cmd",
    "latex",
    "eof",
    "quickfix",
    "grep",
    "man",
    "split-max",
    "buffer",
    "build",
}) do
    require("user." .. m)
end
