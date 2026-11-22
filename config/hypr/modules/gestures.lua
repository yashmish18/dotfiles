-- touchpad gestures.
--   3 or 4 fingers sideways   previous / next workspace
-- each one is tried on its own, so a hyprland that reads one of them differently only
-- loses that gesture (check `hyprctl configerrors`), never the rest of the config.
local function try(spec)
    local ok = pcall(hl.gesture, spec)
    return ok
end

try({ fingers = 3, direction = "horizontal", action = "workspace" })
try({ fingers = 4, direction = "horizontal", action = "workspace" })

-- 4 fingers up / down for the overview would go here; hyprland's lua api takes only a
-- string action, so the overview stays on ctrl + super + ↑ and a click on the workspaces pill.
