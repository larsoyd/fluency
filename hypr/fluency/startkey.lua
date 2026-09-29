-- click fires on release unless the pointer moved, a bound combo shadows it
hl.bind("SUPER + Super_L", hl.dsp.event("fluency-start"), { click = true })
hl.bind("SUPER + CTRL + V", hl.dsp.event("fluency-sound"))
