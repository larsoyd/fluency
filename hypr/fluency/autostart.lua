local xdg = require("fluency.xdgautostart")
local tray = require("fluency.traywait")
local minimize = require("fluency.minimize")

-- desktop ids from FLUENCY_AUTOSTART_MINIMIZED start minimized on the main screen at 0,0
local function main_screen()
    for _, monitor in ipairs(hl.get_monitors() or {}) do
        if monitor.x == 0 and monitor.y == 0 then return monitor end
    end
end

local function minimized()
    local out = {}
    for id in (os.getenv("FLUENCY_AUTOSTART_MINIMIZED") or ""):gmatch("[^,%s]+") do out[id] = true end
    return out
end

-- the screens come one by one at login, the main one may still be missing when hyprland.start runs
local function start_hidden(apps)
    local done = false
    local function launch(monitor)
        if done then return end
        done = true
        -- a screen that cannot be named starts them normally, they must still start
        local found, where = pcall(minimize.workspace, monitor and monitor.name)
        if not found then print(("[autostart] minimized=skipped reason=%q"):format(tostring(where))) end
        for _, app in ipairs(apps) do
            print(("[autostart] name=%s cmd=%q minimized=%s"):format(app.name, app.cmd, found and where or "no"))
            hl.exec_cmd(tray.after(app.cmd, 10), found and { workspace = where .. " silent" } or nil)
        end
    end
    local function try()
        local main = main_screen()
        if main then launch(main) end
    end
    try()
    if done then return end
    hl.on("monitor.added", try)
    hl.on("monitor.layout_changed", try)
    hl.timer(function() launch(main_screen() or hl.get_active_monitor()) end, { timeout = 5000, type = "oneshot" })
end

-- a nested test session must not start the user's apps
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        local apps, skipped = xdg.collect(xdg.dirs(os.getenv), xdg.desktops(os.getenv), xdg.found)
        local hide, hidden = minimized(), {}
        for _, app in ipairs(apps) do
            if hide[app.name] then
                hidden[#hidden + 1] = app
            else
                print(("[autostart] name=%s cmd=%q"):format(app.name, app.cmd))
                hl.exec_cmd(tray.after(app.cmd, 10))
            end
        end
        if #hidden > 0 then start_hidden(hidden) end
        for _, app in ipairs(skipped) do
            print(("[autostart] name=%s result=%q"):format(app.name, app.why))
        end
    end)
end
