local M = {}

function M.workspace(monitor)
    if type(monitor) ~= "string" or monitor == "" then error("refused: no monitor to minimize on", 2) end
    return "special:minimized-" .. monitor
end

-- for a button that runs through hyprctl, it acts on the focused window
function M.active()
    local win = hl.get_active_window()
    if not (win and win.monitor) then return hl.dsp.no_op() end
    return hl.dsp.window.move({ workspace = M.workspace(win.monitor.name), follow = false })
end

return M
