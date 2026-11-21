hl.on("hyprland.start", function()
    -- give the session environment to dbus/systemd activated services (portals, polkit)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- the whole desktop: bar, wallpaper, control center, notifications, lock screen
    hl.exec_cmd("qs -c kajukatli")

    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
