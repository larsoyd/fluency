-- copies made in these apps stay out of the history, password managers also mark their own
local ignore = { "org.keepassxc.KeePassXC", "1Password", "Bitwarden" }
local lib = os.getenv("FLUENCY_PLUGIN_DIR") or (os.getenv("HOME") .. "/.local/lib/fluency")

-- a nested test session runs its own daemon, an install without plugins has none
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("[ -x '" .. lib .. "/fluency-clipd' ] && FLUENCY_CLIP_IGNORE=" .. table.concat(ignore, ",") .. " exec '" .. lib .. "/fluency-clipd'")
    end)
end
