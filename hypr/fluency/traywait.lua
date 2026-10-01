local M = {}

-- electron looks for a tray once at start and never again
local ask = "busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher"
    .. " org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null"

function M.after(cmd, secs)
    local wait = ("until %s | grep -qx 'b true'; do sleep 0.1; done"):format(ask)
    return ('timeout %d sh -c "%s"; %s'):format(secs, wait, cmd)
end

return M
