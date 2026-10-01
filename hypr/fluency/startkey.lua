-- click fires on release unless the pointer moved, a bound combo shadows it
hl.bind("SUPER + Super_L", hl.dsp.event("fluency-start"), { click = true })
hl.bind("SUPER + CTRL + V", hl.dsp.event("fluency-sound"))
hl.bind("SUPER + S", hl.dsp.event("fluency-search"))
hl.bind("SUPER + TAB", hl.dsp.event("fluency-taskview"))
hl.bind("SUPER + N", hl.dsp.event("fluency-notify"))
