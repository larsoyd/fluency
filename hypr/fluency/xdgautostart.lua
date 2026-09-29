-- the xdg autostart spec, the same desktop files kde starts at login
local M = {}

local function has(list, names)
    for item in (list or ""):gmatch("[^;]+") do
        for _, name in ipairs(names) do
            if item == name then return true end
        end
    end
    return false
end

local function quote(s)
    return "'" .. s:gsub("'", [['\'']]) .. "'"
end

function M.parse(text)
    local entry, main = {}, false
    for line in text:gmatch("[^\n]+") do
        local group = line:match("^%[(.*)%]$")
        if group then
            main = group == "Desktop Entry"
        elseif main and not line:match("^#") then
            local k, v = line:match("^([^=]-)%s*=%s*(.*)$")
            if k then entry[k] = v end
        end
    end
    return entry
end

function M.command(entry, desktops, found)
    if entry.Hidden == "true" then return nil, "refused: hidden" end
    if (entry.Type or "Application") ~= "Application" then return nil, "refused: type " .. entry.Type end
    if entry.OnlyShowIn and not has(entry.OnlyShowIn, desktops) then return nil, "refused: only shown in " .. entry.OnlyShowIn end
    if has(entry.NotShowIn, desktops) then return nil, "refused: not shown in " .. entry.NotShowIn end
    if entry["X-GNOME-Autostart-enabled"] == "false" then return nil, "refused: autostart disabled" end
    if entry["X-KDE-autostart-condition"] then return nil, "refused: kde condition" end
    if entry.Terminal == "true" then return nil, "refused: needs a terminal" end
    if entry.TryExec and not found(entry.TryExec) then return nil, "refused: try exec " .. entry.TryExec .. " not found" end
    if not entry.Exec or entry.Exec == "" then return nil, "refused: no exec" end

    local cmd = entry.Exec:gsub("%%%%", "\0"):gsub("%s*%%[fFuUdDnNickvm]", ""):gsub("%z", "%%")
    if entry.Path and entry.Path ~= "" then cmd = "cd " .. quote(entry.Path) .. " && " .. cmd end
    return cmd
end

function M.found(bin)
    if bin:find("/", 1, true) then return os.execute("test -x " .. quote(bin)) == true end
    return os.execute("command -v " .. quote(bin) .. " >/dev/null") == true
end

function M.dirs(getenv)
    local home = getenv("XDG_CONFIG_HOME") or getenv("HOME") .. "/.config"
    local dirs = { home .. "/autostart" }
    for dir in (getenv("XDG_CONFIG_DIRS") or "/etc/xdg"):gmatch("[^:]+") do
        dirs[#dirs + 1] = dir .. "/autostart"
    end
    return dirs
end

function M.desktops(getenv)
    local out = {}
    for name in (getenv("XDG_CURRENT_DESKTOP") or ""):gmatch("[^:]+") do out[#out + 1] = name end
    return out
end

local function files(dir)
    local out, ls = {}, io.popen("ls -1 " .. quote(dir) .. " 2>/dev/null")
    if not ls then return out end
    for name in ls:lines() do
        if name:match("%.desktop$") then out[#out + 1] = name end
    end
    ls:close()
    return out
end

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

-- a file in an earlier dir hides the one of the same name in a later dir
function M.collect(dirs, desktops, found)
    local seen, names = {}, {}
    for _, dir in ipairs(dirs) do
        for _, name in ipairs(files(dir)) do
            if not seen[name] then
                seen[name] = dir .. "/" .. name
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)

    local apps, skipped = {}, {}
    for _, name in ipairs(names) do
        local text = read(seen[name])
        local cmd, why
        if text then
            cmd, why = M.command(M.parse(text), desktops, found)
        else
            why = "refused: unreadable"
        end
        if cmd then
            apps[#apps + 1] = { name = name, cmd = cmd }
        else
            skipped[#skipped + 1] = { name = name, why = why }
        end
    end
    return apps, skipped
end

return M
