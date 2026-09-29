local xdg = require("fluency.xdgautostart")
local minimize = require("fluency.minimize")

-- these start out of the way on a monitor, the taskbar brings them back
local minimized = {
    ["net.lutris.Lutris.desktop"]       = "DP-1",
    ["org.mozilla.Thunderbird.desktop"] = "DP-1",
}

-- a nested test session must not start the user's apps
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        local apps, skipped = xdg.collect(xdg.dirs(os.getenv), xdg.desktops(os.getenv), xdg.found)
        for _, app in ipairs(apps) do
            print(("[autostart] name=%s cmd=%q"):format(app.name, app.cmd))
            local monitor = minimized[app.name]
            if monitor then
                hl.exec_cmd(app.cmd, { workspace = minimize.workspace(monitor) .. " silent" })
            else
                hl.exec_cmd(app.cmd)
            end
        end
        for _, app in ipairs(skipped) do
            print(("[autostart] name=%s result=%q"):format(app.name, app.why))
        end
    end)
end
