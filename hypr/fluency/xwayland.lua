-- outputs with a fractional scale shrink x11 windows and nearest neighbour drops rows of text
hl.config({
    xwayland = {
        use_nearest_neighbor = false,
    },
})
