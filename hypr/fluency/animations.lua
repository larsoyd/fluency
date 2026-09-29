local theme = require("fluency.theme")

for name, points in pairs(theme.curve) do
    hl.curve(name, { type = "bezier", points = points })
end

-- hyprland speed is in tenths of a second, the fluent timings felt rushed so they run a fifth longer
local calm = 1.2
local function speed(ms) return ms * calm / 100 end
local ms = theme.ms

hl.animation({ leaf = "global",        enabled = true, speed = speed(ms.normal), bezier = "decelerate" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = speed(ms.normal), bezier = "decelerate",     style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = speed(ms.fast),   bezier = "accelerate",     style = "popin 90%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = speed(ms.normal), bezier = "decelerate" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = speed(ms.fast),   bezier = "linear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = speed(ms.faster), bezier = "linear" })
hl.animation({ leaf = "fadeSwitch",    enabled = true, speed = speed(ms.fast),   bezier = "easy" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = speed(ms.fast),   bezier = "easy" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = speed(ms.normal), bezier = "easy" })
hl.animation({ leaf = "border",        enabled = true, speed = speed(ms.fast),   bezier = "easy" })
hl.animation({ leaf = "borderangle",   enabled = false })
hl.animation({ leaf = "layersIn",      enabled = true, speed = speed(ms.normal), bezier = "decelerate_max", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = speed(ms.fast),   bezier = "accelerate",     style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = speed(ms.fast),   bezier = "linear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = speed(ms.faster), bezier = "linear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = speed(ms.normal), bezier = "decelerate",     style = "slidefade 20%" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = speed(ms.normal), bezier = "decelerate" })
