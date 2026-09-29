-- the side monitors scale x11 windows down and nearest neighbour drops rows of text
hl.config({
    xwayland = {
        use_nearest_neighbor = false,
    },
})
