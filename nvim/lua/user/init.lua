for _, m in ipairs({
    "remaps",
    "netrw",
    "term",
    "cursor-jump",
    "comments",
    "indent",
    "func-telescope",
    "cmd",
}) do
    require("user." .. m)
end

