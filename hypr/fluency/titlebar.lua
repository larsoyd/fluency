local theme = require("fluency.theme")
local c = theme.color
local machine = require("fluency.machine")

-- tests point this at a fresh build
local lib = os.getenv("FLUENCY_PLUGIN_DIR") or (os.getenv("HOME") .. "/.local/lib/fluency")

-- a plugin built for another hyprland refuses to load, so the loader rebuilds it first
hl.on("hyprland.start", function()
    hl.exec_cmd("'" .. lib .. "/plugins/fluency-plugins.sh' load '" .. lib .. "'")
end)

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
                button_icon_size           = 16,
                bar_part_of_window         = true,
                bar_precedence_over_border = true,
                on_double_click            = "hyprctl dispatch '" .. maximize .. "'",
                icon_theme                 = machine.icon_theme or "",
            },
        },
    })

    -- fluent system icons regular, the icon name and its codepoint
    local glyphs = {
        close    = { "dismiss_16", 0xf368 },
        maximize = { "maximize_16", 0xf533 },
        minimize = { "subtract_16", 0xebcf },
    }

    -- right to left, the red of close has no source yet
    local buttons = {
        { glyph = glyphs.close, call = "hl.dsp.window.close()", hover = "rgba(c42b1cff)", pressed = "rgba(c42b1ce6)", hover_fg = c.text },
        { glyph = glyphs.maximize, call = maximize },
        { glyph = glyphs.minimize, call = [[require("fluency.minimize").active()]] },
    }
    for _, b in ipairs(buttons) do
        hl.plugin.fluencytitlebar.add_button({
            bg_color       = "rgba(00000000)",
            fg_color       = c.text,
            hover_color    = b.hover or c.subtle_hover,
            pressed_color  = b.pressed or c.subtle_pressed,
            hover_fg_color = b.hover_fg,
            size           = 46,
            icon           = utf8.char(b.glyph[2]),
            action         = "hyprctl dispatch '" .. b.call .. "'",
        })
    end

    -- wayland apps say whether they draw their own titlebar, steam runs under xwayland and says nothing
    -- its tiled client has its own caption buttons, its login and update windows float and do not
    hl.window_rule({
        name  = "steam-main",
        match = { class = "^steam$", float = false },
        ["fluencytitlebar:no_bar"] = true,
    })
end
