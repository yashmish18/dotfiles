-- touchpad gestures.
--   3 or 4 fingers sideways   previous / next workspace
--   4 fingers up              overview: every workspace and its windows
--   4 fingers down            close whatever the shell has open
-- each one is tried on its own, so a hyprland that reads one of them differently only
-- loses that gesture (check `hyprctl configerrors`), never the rest of the config.
local function try(spec)
    local ok = pcall(hl.gesture, spec)
    return ok
end

try({ fingers = 3, direction = "horizontal", action = "workspace" })
try({ fingers = 4, direction = "horizontal", action = "workspace" })

local function shell_gesture(dir, name)
    -- newer lua configs take a dispatcher object; older ones a dispatcher name + argument
    if not try({ fingers = 4, direction = dir, action = hl.dsp.global(KK.shell .. ":" .. name) }) then
        try({ fingers = 4, direction = dir, action = "dispatcher", dispatcher = "global", args = KK.shell .. ":" .. name })
    end
end
shell_gesture("up", "overview")
shell_gesture("down", "close")
