local xdg = require("fluency.xdgautostart")
local tray = require("fluency.traywait")
local minimize = require("fluency.minimize")

-- desktop ids from FLUENCY_AUTOSTART_MINIMIZED start minimized on the main screen at 0,0
local function main_screen()
    for _, monitor in ipairs(hl.get_monitors() or {}) do
        if monitor.x == 0 and monitor.y == 0 then return monitor end
    end
    return hl.get_active_monitor()
end

local function minimized()
    local out = {}
    for id in (os.getenv("FLUENCY_AUTOSTART_MINIMIZED") or ""):gmatch("[^,%s]+") do out[id] = true end
    return out
end

-- a nested test session must not start the user's apps
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        local apps, skipped = xdg.collect(xdg.dirs(os.getenv), xdg.desktops(os.getenv), xdg.found)
        local hide, monitor = minimized(), main_screen()
        -- a screen that cannot be named starts them normally, the rest of the apps must still start
        local found, where = pcall(minimize.workspace, monitor and monitor.name)
        if next(hide) and not found then print(("[autostart] minimized=skipped reason=%q"):format(tostring(where))) end
        for _, app in ipairs(apps) do
            print(("[autostart] name=%s cmd=%q"):format(app.name, app.cmd))
            if hide[app.name] and found then
                hl.exec_cmd(tray.after(app.cmd, 10), { workspace = where .. " silent" })
            else
                hl.exec_cmd(tray.after(app.cmd, 10))
            end
        end
        for _, app in ipairs(skipped) do
            print(("[autostart] name=%s result=%q"):format(app.name, app.why))
        end
    end)
end
