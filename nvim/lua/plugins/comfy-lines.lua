return {
    {
        'mluders/comfy-line-numbers.nvim',
        config = function()
            local labels = {}
            local digits = { "1", "2", "3", "4" }

            local function add(prefix, remaining)
                if remaining == 0 then
                    labels[#labels + 1] = prefix
                    return
                end

                for _, digit in ipairs(digits) do
                    add(prefix .. digit, remaining - 1)
                end
            end

            for width = 1, 3 do
                add("", width)
            end

            require("comfy-line-numbers").config.labels = labels
        end,
    },
}
