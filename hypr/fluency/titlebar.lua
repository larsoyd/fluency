local theme = require("fluency.theme")
local c = theme.color

-- tests point this at a fresh build
local lib = os.getenv("FLUENCY_PLUGIN_DIR") or (os.getenv("HOME") .. "/.local/lib")
hl.plugin.load(lib .. "/libfluencyminimize.so")
hl.plugin.load(lib .. "/libfluencytitlebar.so")

local maximize = [[hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })]]

-- plugins load after the config ran once, their keys and functions exist from the second run on
if hl.plugin.fluencytitlebar then
    hl.config({
        plugin = {
            fluencytitlebar = {
                bar_height                 = 32,
                bar_color                  = c.base,
                ["col.text"]               = c.text,
                bar_text_font              = theme.font,
                bar_text_size              = 10,
                bar_text_align             = "left",
                title_padding              = 16,
                bar_padding                = 0,
                bar_button_padding         = 0,
                button_icon_size           = 10,
                bar_part_of_window         = true,
                bar_precedence_over_border = true,
                on_double_click            = "hyprctl dispatch '" .. maximize .. "'",
            },
        },
    })

    -- right to left, glyphs of segoe fluent icons, the red of close has no source yet
    local buttons = {
        { glyph = 0xe8bb, call = "hl.dsp.window.close()", hover = "rgba(c42b1cff)", pressed = "rgba(c42b1ce6)", hover_fg = c.text },
        { glyph = 0xe922, call = maximize },
        { glyph = 0xe921, call = [[require("fluency.minimize").active()]] },
    }
    for _, b in ipairs(buttons) do
        hl.plugin.fluencytitlebar.add_button({
            bg_color       = "rgba(00000000)",
            fg_color       = c.text,
            hover_color    = b.hover or c.subtle_hover,
            pressed_color  = b.pressed or c.subtle_pressed,
            hover_fg_color = b.hover_fg,
            size           = 46,
            icon           = utf8.char(b.glyph),
            action         = "hyprctl dispatch '" .. b.call .. "'",
        })
    end

    -- these draw a titlebar of their own
    hl.window_rule({
        name  = "own-titlebar",
        match = { class = "^(firefox|Mullvad VPN|aquamarine)$" },
        ["fluencytitlebar:no_bar"] = true,
    })

    -- the tiled steam client has its own caption buttons, its login and update windows float and do not
    hl.window_rule({
        name  = "steam-main",
        match = { class = "^steam$", float = false },
        ["fluencytitlebar:no_bar"] = true,
    })
end
