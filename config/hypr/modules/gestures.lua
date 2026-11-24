-- touchpad gestures.
--   4 fingers sideways   previous / next workspace (past the last one makes a new one,
--                        even from an empty workspace)
--   4 fingers up         every workspace and its windows (the shell's overview)
--   4 fingers down       close whatever the shell has open
--
-- every call is guarded: the gesture api differs between hyprland versions (a lua function as
-- the action on some, a named action on others), and a version that doesn't know one form must
-- not paint "your config has errors" over the screen. each custom gesture tries the function
-- form, then a dispatcher form, and is skipped quietly if neither is understood.
local function shell_cmd(...)
    -- build the command now: lua can't reach `...` from inside the inner function
    return "qs -c " .. KK.shell .. " ipc call shell " .. table.concat({ ... }, " ")
end

local function custom(direction, cmd)
    local function try(action_fields)
        local spec = { fingers = 4, direction = direction }
        for k, v in pairs(action_fields) do spec[k] = v end
        return pcall(hl.gesture, spec)
    end
    if try({ action = function() hl.exec_cmd(cmd) end }) then return end
    if try({ action = "dispatcher", dispatcher = "exec", arg = cmd }) then return end
    try({ action = "exec", arg = cmd })
end

pcall(hl.gesture, { fingers = 4, direction = "horizontal", action = "workspace" })
custom("up", shell_cmd("overlay", "overview"))
custom("down", shell_cmd("close"))

pcall(hl.config, {
    gestures = {
        workspace_swipe_create_new = true,   -- swiping past the last workspace opens a new one
        workspace_swipe_use_r = true,        -- count empty workspaces too, so a swipe from one works
    },
})
