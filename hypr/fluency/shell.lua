local surfaces = {
    { name = "fluency-taskbar" },
    { name = "fluency-flyout", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-toast", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-menu", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-start", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-search", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-osd", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-quick", ignore_alpha = 0.5, no_anim = true },
    { name = "fluency-jump", ignore_alpha = 0.5, no_anim = true },
    -- the menu fades out whole, a low threshold keeps its blur until the last frame
    { name = "fluency-context", ignore_alpha = 0.02, no_anim = true },
    { name = "fluency-notify", ignore_alpha = 0.02, no_anim = true },
    -- the dim fades in, a low threshold blurs the desktop behind it from the first frame
    { name = "fluency-taskview", ignore_alpha = 0.02, no_anim = true },
    { name = "fluency-switch", ignore_alpha = 0.02, no_anim = true },
}

for _, surface in ipairs(surfaces) do
    hl.layer_rule({
        name         = surface.name .. "-acrylic",
        match        = { namespace = "^" .. surface.name .. "$" },
        blur         = true,
        ignore_alpha = surface.ignore_alpha,
        no_anim      = surface.no_anim,
    })
end

-- a nested test session brings its own shell
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("qs --no-duplicate --log-rules qt.svg.warning=false -p ~/.local/share/fluency/shell")
    end)
end
