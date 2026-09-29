local minimize = require("fluency.minimize")

local M = {}

-- unset only acts on the mode the window is in
local modes = { "maximized", "fullscreen" }

function M.new()
    return { focus_changes = 0 }
end

function M.focus_changed(state)
    state.focus_changes = state.focus_changes + 1
end

function M.down(state, win)
    if not win then return {} end
    local mode = modes[win.fullscreen]
    if mode then return { { "fullscreen", { mode = mode, action = "unset" } } } end
    local monitor = win.monitor and win.monitor.name
    if not monitor then return {} end
    state.pending = { window = "address:" .. win.address, workspace = win.workspace.id, at = state.focus_changes }
    return { { "move", { workspace = minimize.workspace(monitor), follow = false } } }
end

-- minimizing moves focus once so one change still counts as right after
function M.up(state, win)
    local pending = state.pending
    state.pending = nil
    if pending and state.focus_changes - pending.at <= 1 then
        return { { "move", { window = pending.window, workspace = pending.workspace } } }
    end
    if not win then return {} end
    return { { "fullscreen", { mode = "maximized", action = "set" } } }
end

return M
