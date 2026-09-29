local minimize = require("fluency.minimize")

-- without a rule a new workspace lands on the focused monitor and takes the window with it
local function bind(monitor)
    hl.workspace_rule({ workspace = minimize.workspace(monitor.name), monitor = monitor.name })
end

for _, monitor in ipairs(hl.get_monitors()) do bind(monitor) end
hl.on("monitor.added", bind)
