-- click fires on release unless the pointer moved, a bound combo shadows it
hl.bind("SUPER + Super_L", hl.dsp.event("fluency-start"), { click = true })
hl.bind("SUPER + CTRL + V", hl.dsp.event("fluency-sound"))
hl.bind("SUPER + S", hl.dsp.event("fluency-search"))
hl.bind("SUPER + TAB", hl.dsp.event("fluency-taskview"))
hl.bind("SUPER + N", hl.dsp.event("fluency-notify"))
hl.bind("SUPER + V", hl.dsp.event("fluency-clipboard"))
-- the app gets a key between alt down and up, or a lone alt opens its menu bar
local function switch(event)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = "ALT", key = "F24", state = "down" }))
        hl.dispatch(hl.dsp.send_key_state({ mods = "ALT", key = "F24", state = "up" }))
        hl.dispatch(hl.dsp.event(event))
    end
end
hl.bind("ALT + TAB", switch("fluency-switch-next"))
hl.bind("ALT + SHIFT + TAB", switch("fluency-switch-prev"))
hl.bind("ALT + ESCAPE", hl.dsp.event("fluency-switch-cancel"))
-- ignore_mods and transparent let the release through after tab, non_consuming leaves alt to apps
hl.bind("ALT + Alt_L", hl.dsp.event("fluency-switch-done"), { release = true, ignore_mods = true, transparent = true, non_consuming = true })
