for _, m in ipairs({
    "remaps",
    "netrw",
    "tab",
    "term",
    "cursor-jump",
    "comments",
    "indent",
    "func-telescope",
    "cmd",
    "binary",
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
