local winkeys = require("fluency.winkeys")
local binds = require("fluency.binds")

local keys = winkeys.new()
local function run(steps)
    for _, step in ipairs(steps) do hl.dispatch(hl.dsp.window[step[1]](step[2])) end
end

-- up maximizes or restores what down just minimized
hl.on("window.active", function() winkeys.focus_changed(keys) end)
binds.bind("maximize", function() run(winkeys.up(keys, hl.get_active_window())) end)
binds.bind("minimize", function() run(winkeys.down(keys, hl.get_active_window())) end)
binds.bind("close", hl.dsp.window.close())
