-- apps ask to be maximised all the time. let the tiler decide.
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- xwayland drag fix (from the hyprland defaults)
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- small utility windows float in the middle
local floaters = {
    "^(org\\.pulseaudio\\.pavucontrol|pavucontrol)$",
    "^(nm-connection-editor)$",
    "^(\\.?blueman-manager(-wrapped)?)$",
    "^(org\\.kde\\.ark)$",
    "^(xdg-desktop-portal-gtk)$",
    "^(qt6ct|nwg-look)$",
    "^(kk-float)$",
}
for i, cls in ipairs(floaters) do
    hl.window_rule({
        name   = "float-" .. i,
        match  = { class = cls },
        float  = true,
        center = true,
        size   = { "monitor_w * 0.42", "monitor_h * 0.6" },
    })
end

-- the shell's settings window: floating, centred, a comfortable size
hl.window_rule({
    name   = "kk-settings",
    match  = { title = "^(Kajukatli Settings)$" },
    float  = true,
    center = true,
    size   = { "min(1040, monitor_w * 0.8)", "min(720, monitor_h * 0.85)" },
})

-- file pickers
hl.window_rule({
    name   = "float-dialogs",
    match  = { title = "^(Open File|Save File|Save As|Open Folder|Select a File|Choose Files|File Upload).*" },
    float  = true,
    center = true,
})

-- picture in picture: corner, pinned, keeps its shape
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin   = true,
    keep_aspect_ratio = true,
    size  = { "monitor_w * 0.24", "monitor_h * 0.24" },
    move  = { "monitor_w * 0.75 - 12", "monitor_h * 0.75 - 12" },
})

-- no sleeping halfway through a film
hl.window_rule({ name = "idle-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- the shell animates itself. hyprland's layer animations would fight it.
hl.layer_rule({ name = "kk-no-anim", match = { namespace = "^kajukatli.*" }, no_anim = true })

-- frosted glass behind the bar, its panels, the dock and toasts. ignore_alpha keeps the blur
-- to the drawn shapes, not the whole (mostly transparent) surface.
hl.layer_rule({ name = "kk-glass", match = { namespace = "^kajukatli-(bar|dock|notifications)$" }, blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ name = "kk-selection", match = { namespace = "^(selection|hyprpicker)$" }, no_anim = true })
