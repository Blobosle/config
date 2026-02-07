for _, m in ipairs({
    "remaps",
    "netrw",
    "term",
    "cursor-jump",
    "comments",
    "indent",
    "func-telescope",
    "cmd",
    "latex",
    "quickfix",
    "grep",
    "man",
}) do
    require("user." .. m)
end

