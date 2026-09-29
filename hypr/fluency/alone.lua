-- a lone tiled or maximized window fills its monitor flat, a second tiled window brings the gaps back
for _, sel in ipairs({ "w[tv1]s[false]", "f[1]s[false]" }) do
    hl.workspace_rule({ workspace = sel, gaps_in = 0, gaps_out = 0 })

    hl.window_rule({
        name  = "alone-" .. sel:sub(1, 1),
        match = { float = false, workspace = sel },

        border_size = 0,
        rounding    = 0,
        no_shadow   = true,
    })
end
