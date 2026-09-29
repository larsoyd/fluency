local winkeys = require("fluency.winkeys")

local keys = winkeys.new()
local function run(steps)
    for _, step in ipairs(steps) do hl.dispatch(hl.dsp.window[step[1]](step[2])) end
end

-- up maximizes or restores what down just minimized
hl.on("window.active", function() winkeys.focus_changed(keys) end)
hl.bind("SUPER + up",   function() run(winkeys.up(keys, hl.get_active_window())) end)
hl.bind("SUPER + down", function() run(winkeys.down(keys, hl.get_active_window())) end)
hl.bind("ALT + F4", hl.dsp.window.close())
