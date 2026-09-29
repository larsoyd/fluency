local theme = require("fluency.theme")
local c = theme.color

-- kawase spreads about size times two per pass
local blur_passes = 3

hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 8,

        border_size = 1,

        col = {
            active_border         = c.accent,
            inactive_border       = c.stroke,
            nogroup_border        = c.stroke,
            nogroup_border_active = c.critical,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",

        snap = {
            enabled      = true,
            respect_gaps = true,
        },
    },

    decoration = {
        rounding       = theme.radius.overlay,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        dim_special = theme.smoke,
        dim_around  = theme.smoke,

        shadow = {
            enabled        = true,
            range          = theme.shadow.range,
            offset         = { 0, theme.shadow.offset },
            render_power   = 3,
            color          = c.shadow_key,
            color_inactive = c.shadow_ambient,
        },

        blur = {
            enabled = true,
            size    = math.ceil(theme.blur.radius / 2 ^ blur_passes),
            passes  = blur_passes,
            noise   = theme.blur.noise,
            popups  = true,
            xray    = true,
        },
    },

    group = {
        col = {
            border_active          = c.accent,
            border_inactive        = c.stroke,
            border_locked_active   = c.caution,
            border_locked_inactive = c.stroke,
        },

        groupbar = {
            font_family         = theme.font,
            font_size           = 10,
            height              = 20,
            indicator_height    = 3,
            rounding            = 1,
            text_color          = c.text,
            text_color_inactive = c.text_dim,

            col = {
                active          = c.accent_light,
                inactive        = c.stroke,
                locked_active   = c.caution,
                locked_inactive = c.stroke,
            },
        },
    },

    animations = {
        enabled = true,
    },
})
