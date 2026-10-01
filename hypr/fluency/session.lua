local lib = os.getenv("FLUENCY_PLUGIN_DIR") or (os.getenv("HOME") .. "/.local/lib/fluency")

-- tells the shell when the session locks, a nested test session runs its own
if os.getenv("FLUENCY_NESTED") ~= "1" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("test -x '" .. lib .. "/fluency-sessiond' && exec '" .. lib .. "/fluency-sessiond'")
    end)
end
