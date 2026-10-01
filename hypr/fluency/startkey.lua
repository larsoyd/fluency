local binds = require("fluency.binds")

-- click fires on release unless the pointer moved, a bound combo shadows it
binds.bind("start", hl.dsp.event("fluency-start"), { click = true })
binds.bind("sound", hl.dsp.event("fluency-sound"))
binds.bind("search", hl.dsp.event("fluency-search"))
binds.bind("taskview", hl.dsp.event("fluency-taskview"))
binds.bind("notify", hl.dsp.event("fluency-notify"))
binds.bind("clipboard", hl.dsp.event("fluency-clipboard"))
-- the app gets a key between alt down and up, or a lone alt opens its menu bar
local function switch(event)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = "ALT", key = "F24", state = "down" }))
        hl.dispatch(hl.dsp.send_key_state({ mods = "ALT", key = "F24", state = "up" }))
        hl.dispatch(hl.dsp.event(event))
    end
end
binds.bind("alt-tab", switch("fluency-switch-next"))
binds.bind("alt-shift-tab", switch("fluency-switch-prev"))
binds.bind("alt-escape", hl.dsp.event("fluency-switch-cancel"))
-- ignore_mods and transparent let the release through after tab, non_consuming leaves alt to apps
binds.bind("alt-release", hl.dsp.event("fluency-switch-done"), { release = true, ignore_mods = true, transparent = true, non_consuming = true })
