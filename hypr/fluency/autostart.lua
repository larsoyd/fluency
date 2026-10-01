local xdg = require("fluency.xdgautostart")
local tray = require("fluency.traywait")
local minimize = require("fluency.minimize")

-- desktop ids from FLUENCY_AUTOSTART_MINIMIZED start on the minimized workspace of the focused monitor
local function minimized()
    local out = {}
    for id in (os.getenv("FLUENCY_AUTOSTART_MINIMIZED") or ""):gmatch("[^,%s]+") do out[id] = true end
    return out
end

-- a nested test session must not start the user's apps
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        local apps, skipped = xdg.collect(xdg.dirs(os.getenv), xdg.desktops(os.getenv), xdg.found)
        local hide, monitor = minimized(), hl.get_active_monitor()
        for _, app in ipairs(apps) do
            print(("[autostart] name=%s cmd=%q"):format(app.name, app.cmd))
            if hide[app.name] and monitor then
                hl.exec_cmd(tray.after(app.cmd, 10), { workspace = minimize.workspace(monitor.name) .. " silent" })
            else
                hl.exec_cmd(tray.after(app.cmd, 10))
            end
        end
        for _, app in ipairs(skipped) do
            print(("[autostart] name=%s result=%q"):format(app.name, app.why))
        end
    end)
end
