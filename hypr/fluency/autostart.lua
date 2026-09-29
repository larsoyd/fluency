local xdg = require("fluency.xdgautostart")

-- a nested test session must not start the user's apps
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        local apps, skipped = xdg.collect(xdg.dirs(os.getenv), xdg.desktops(os.getenv), xdg.found)
        for _, app in ipairs(apps) do
            print(("[autostart] name=%s cmd=%q"):format(app.name, app.cmd))
            hl.exec_cmd(app.cmd)
        end
        for _, app in ipairs(skipped) do
            print(("[autostart] name=%s result=%q"):format(app.name, app.why))
        end
    end)
end
