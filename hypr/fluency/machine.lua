-- what the installer found for this machine, then what the user set, the user's keys win
local function load(name)
    local found, got = pcall(require, name)
    if not found then return {} end
    if type(got) ~= "table" then error(("refused: %s must return a table, got %s"):format(name, type(got)), 3) end
    return got
end

local generated, mine = load("fluency.generated"), load("fluency.local")
local env = {}
for name, value in pairs(generated.env or {}) do env[name] = value end
for name, value in pairs(mine.env or {}) do env[name] = value end

return { icon_theme = mine.icon_theme or generated.icon_theme, env = env, binds = mine.binds or {} }
