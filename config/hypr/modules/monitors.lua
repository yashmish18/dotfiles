-- every screen at 100% by default. settings → display changes it live and remembers it.
-- run `hyprctl monitors` to see names, then add exact lines to user.lua, e.g.
-- hl.monitor({ output = "eDP-1", mode = "2560x1600@165", position = "0x0", scale = "1.6" })
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",      -- 100%. "auto" picks 1.25 on many laptops; change it in settings → display
})
