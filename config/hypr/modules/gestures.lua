-- touchpad gestures.
--   3 fingers sideways   previous / next workspace (past the last one makes a new one)
--   4 fingers up         every workspace and its windows (the shell's overview)
--   4 fingers down       close whatever the shell has open
--
-- custom gestures take a lua function as their action (hyprland ≥ 0.56). the shell is
-- reached over its ipc, which works from inside a gesture where hl.dsp.* calls don't.
local function shell(...)
    return function()
        hl.exec_cmd("qs -c " .. KK.shell .. " ipc call shell " .. table.concat({ ... }, " "))
    end
end

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = shell("overlay", "overview") })
hl.gesture({ fingers = 4, direction = "down", action = shell("close") })

hl.config({
    gestures = {
        workspace_swipe_create_new = true,   -- swiping past the last workspace opens a new one
    },
})
