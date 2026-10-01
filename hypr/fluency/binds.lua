local machine = require("fluency.machine")

-- every key fluency binds has a name, local.lua turns one off with false or moves it to another combo
local defaults = {
    start = "SUPER + Super_L",
    sound = "SUPER + CTRL + V",
    search = "SUPER + S",
    taskview = "SUPER + TAB",
    notify = "SUPER + N",
    clipboard = "SUPER + V",
    ["alt-tab"] = "ALT + TAB",
    ["alt-shift-tab"] = "ALT + SHIFT + TAB",
    ["alt-escape"] = "ALT + ESCAPE",
    ["alt-release"] = "ALT + Alt_L",
    maximize = "SUPER + up",
    minimize = "SUPER + down",
    close = "ALT + F4",
}

local combos = {}
for name, combo in pairs(defaults) do combos[name] = combo end
for name, choice in pairs(machine.binds) do
    if defaults[name] == nil then error(("refused: unknown bind %s"):format(name), 2) end
    if choice ~= false and type(choice) ~= "string" then error(("refused: bind %s must be false or a combo, got %s"):format(name, type(choice)), 2) end
    combos[name] = choice
end

local owners = {}
for name, combo in pairs(combos) do
    if combo then
        local other = owners[combo]
        if other then
            local first, second = other, name
            if first > second then first, second = second, first end
            error(("refused: %s is bound twice, by %s and %s"):format(combo, first, second), 2)
        end
        owners[combo] = name
    end
end

local M = {}

function M.bind(name, action, flags)
    local combo = combos[name]
    if combo == nil then error("refused: unknown bind " .. name, 2) end
    if combo then hl.bind(combo, action, flags) end
end

return M
