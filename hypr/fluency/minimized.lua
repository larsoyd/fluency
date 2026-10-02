local minimize = require("fluency.minimize")

-- a minimized window keeps its box, one that opened here has none and gets the work area
hl.layout.register("fluency-keep", {
    recalculate = function(ctx)
        for _, target in ipairs(ctx.targets) do
            local box = target.box
            target:place((box.w > 0 and box.h > 0) and box or ctx.area)
        end
    end,
})

-- without a rule a new workspace lands on the focused monitor and takes the window with it
local function bind(monitor)
    hl.workspace_rule({ workspace = minimize.workspace(monitor.name), monitor = monitor.name, layout = "lua:fluency-keep" })
end

for _, monitor in ipairs(hl.get_monitors()) do bind(monitor) end
hl.on("monitor.added", bind)
