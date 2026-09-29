-- fluency dark, values from fluent 2 tokens
return {
    color = {
        accent         = "rgba(0078d4ff)",
        accent_light   = "rgba(4cc2ffff)",
        accent_dark    = "rgba(003e92ff)",
        base           = "rgba(202020ff)",
        layer          = "rgba(3a3a3a4c)",
        stroke         = "rgba(75757566)",
        text           = "rgba(ffffffff)",
        text_dim       = "rgba(ffffffc5)",
        shadow_key     = "rgba(00000047)",
        shadow_ambient = "rgba(0000003d)",
        critical       = "rgba(ff99a4ff)",
        caution        = "rgba(fce100ff)",
        subtle_hover   = "rgba(ffffff0f)",
        subtle_pressed = "rgba(ffffff0a)",
    },

    font   = "Selawik",
    radius = { control = 4, overlay = 8 },
    smoke  = 0.3,

    -- acrylic is a 30px gaussian with 2% noise
    blur = { radius = 30, noise = 0.02 },

    -- shadow28 in fluent is a 0 14px 28px key shadow
    shadow = { offset = 14, range = 28 },

    ms = { faster = 83, fast = 167, normal = 250 },
    curve = {
        decelerate     = { { 0, 0 },     { 0, 1 } },
        decelerate_max = { { 0.1, 0.9 }, { 0.2, 1 } },
        accelerate     = { { 0.9, 0.1 }, { 1, 0.2 } },
        easy           = { { 0.33, 0 },  { 0.67, 1 } },
        linear         = { { 0, 0 },     { 1, 1 } },
    },
}
